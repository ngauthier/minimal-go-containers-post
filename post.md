# Building minimal containers for go applications

1. the app
2. using onbuild and golang
3. size
4. building and adding ("no such file or directory" when running)
5. statically building
6. "Get https://google.com: x509: failed to load system roots and no roots provided"
7. add certs to repo and add into expected path
8. final size

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
