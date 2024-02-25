# Special Edition Using CGI, 2nd Edition


From my perspective, CGI serves as the bedrock for dynamic web development. Although direct employment of CGI technology has waned in contemporary practices, many modern dynamic web frameworks owe their roots to CGI principles.

Exploring the techniques employed by web pioneers during the 90s can be quite intriguing.

I'll list all the resources I utilized to navigate through this book.

## Building the base container image
```
podman build -t special-edition-cgi-httpd -f Dockerfile.httpd
```

## Start the container for development
```
cd chapXX
alias cgi='podman run -it --name cgi --rm --security-opt label=disable -p 8080:80 -v .:/var/www/cgi-bin special-edition-cgi-httpd'
cgi
```

## Links
Link to the publisher site of this book: [https://www.informit.com/store/special-edition-using-cgi-9780789711397](https://www.informit.com/store/special-edition-using-cgi-9780789711397)

Source code from the book - Special Edition Using CGI, 2nd Edition: [https://www.informit.com/content/images/0789711397/sourcecode/allcode.zip](https://www.informit.com/content/images/0789711397/sourcecode/allcode.zip)
