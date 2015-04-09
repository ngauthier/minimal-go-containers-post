# Building minimal docker containers for go applications

There are great official and community supported containers for many programming languages, including Go. But these containers can be quite large in size. In this post, we'll walk through a comparison of methods for building containers for Go applications, then show a way to statically build go apps for containerization that are extremely small.

## Part One: Our "app"

We need something to test for our app, so let's make something pretty small: we're going to fetch google.com and output the size of the html we fetch:

```
package main

import (
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
)

func main() {
	resp, err := http.Get("https://google.com")
	check(err)
	body, err := ioutil.ReadAll(resp.Body)
	check(err)
	fmt.Println(len(body))
}

func check(err error) {
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}
```

If we run this, it will just print out some numbers. For me it was around 17k. I purposefully decided to do something with SSL for reasons we'll explain later :-).

## Part 2: Dockerize

Following the official Docker image for Go, we would write an "onbuild" Dockerfile like this:

```
FROM golang:onbuild
```

The "onbuild" images assume your project structure is standard and will build you app like any Go app. If you want more control, you could use their standard Go base image and compile yourself:

```
FROM golang:latest
RUN mkdir /app
ADD . /app/
WORKDIR /app
RUN go build -o main .
CMD ["/app/main"]
```

This is nice if you have a Makefile or something else non-standard you have to do when you're building your app. We could download some assets from a CDN or maybe add them in from another project, or maybe we want to run our tests within the container.

So, Dockerizing Go apps is pretty straightforward, especially since we don't have any services or ports we need access to or to export.

But, there's one big drawback to the official images: they're really big. Let's take a look:

```
REPOSITORY          TAG                                        IMAGE ID            CREATED              VIRTUAL SIZE
example-onbuild     latest                                     9dfb1bbac2b8        19 minutes ago       520.7 MB
example-golang      latest                                     02e19291523e        19 minutes ago       520.7 MB
golang              onbuild                                    3be7ee2ec1ae        9 days ago           514.9 MB
golang              1.4.2                                      121a93c90463        9 days ago           514.9 MB
golang              latest                                     121a93c90463        9 days ago           514.9 MB
```

The bases are 514.9MB and our app adds just 5.8MB to that. Wow. So for our *compiled* application we still need 514.9MB of dependencies? How did that happen?

The answer is that our app was compiled *inside* the container. That means the container needs Go installed, and that means it needs Go's dependencies, which means we need a package manager and really an entire OS. In fact, if you look at the Dockerfile for golang:1.4, it starts with debian jessie, installs the gcc compiler and some build tools, curls down go, and installs it. So we pretty much have a whole debian server and the Go toolkit just to run our tiny app. What can we do?

## Part 3: Compile!

The way to do better is to do something a little ... off the beaten path. What we're going to do is compile Go in our working directory, then add the binary into the container. That means a simple `docker build` won't work. We need a multi-step container build:

```
go build -o main .
docker build -t example-scratch -f Dockerfile.scratch .
```

And Dockerfile.scratch is simply:

```
FROM scratch
ADD main /
CMD ["/main"]
```

So what's scratch? Scratch is a special docker image that's empty. It's truly 0B:

```
REPOSITORY          TAG                                        IMAGE ID            CREATED              VIRTUAL SIZE
example-scratch     latest                                     ca1ad50c9256        About a minute ago   5.60 MB
scratch             latest                                     511136ea3c5a        22 months ago        0 B
```

Also, our container is just that 5.6MB! Cool! But there's one problem:

```
$ docker run -it example-scratch
no such file or directory
```

OOOOOOOOK, what does that mean?! Took me a while to figure it out, but our Go binary is looking for libraries on the operating system it's running in. We compiled our app, but it still is dynamically linked to the libraries it needs to run (all the C libraries it binds too). Unfortunately, scratch is empty, so there are no libraries and no loadpath for it to look in. What we have to do is modify our build script to statically compile our app with all libraries built in:

```
CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .
```

We're disabling cgo which gives us a static binary. We're also setting the OS to linux (in case someone builds this on a mac or windows) and the `-a` flag means to rebuild all the packages we're using, which means all the imports will be rebuilt with cgo disabled. Now we have a static binary! Let's try it out:

```
$ docker run -it example-scratch
Get https://google.com: x509: failed to load system roots and no roots provided
```

Great, now what? This is why I chose to use SSL in our example. This is a really common gotcha for this scenario: for making SSL requests we need the SSL root certificates.

TODO: add in root certs, compare final size

```
REPOSITORY          TAG                                        IMAGE ID            CREATED              VIRTUAL SIZE
example-scratch     latest                                     ca1ad50c9256        About a minute ago   6.12 MB
example-onbuild     latest                                     9dfb1bbac2b8        19 minutes ago       520.7 MB
example-golang      latest                                     02e19291523e        19 minutes ago       520.7 MB
golang              onbuild                                    3be7ee2ec1ae        9 days ago           514.9 MB
golang              1.4.2                                      121a93c90463        9 days ago           514.9 MB
golang              latest                                     121a93c90463        9 days ago           514.9 MB
scratch             latest                                     511136ea3c5a        22 months ago        0 B
```
