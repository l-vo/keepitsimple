# Keepitsimple

## Goal
This project is a docker container for my Hexo blog "Keep it Simple"

## Requirements
In production, this project requires:
- a docker network named `keepitsimple`
- Python 2.7
- the docker Python sdk (`pip install docker`)
- an environment variable `UPSTREAMS_LOCATION` with the file where the Nginx upstream will be written. `{project}` placeholder can be user and will be replaced by *keepitsimple*.
- an environment variable `DOCKER_NAMESPACE` with the namespace used for created production docker image 

## Development usage
Start the containers:
```bash
$ make start
```
Stop the containers:
```bash
$ make stop
```

## Usage
For launching hexo commands, log into hexo container:
```bash
$ make exec
```

Create a new article:
```bash
$ hexo new draft "My Title"
```

Publish an article:
```bash
$ hexo publish "My Title"
```

Generate static files (these files will be available through the nginx container):
```bash
$ hexo generate
```