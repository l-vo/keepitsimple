# Keepitsimple

## Goal
This project is a docker container for my Hexo blog "Keep it Simple"

## Requirements
In production, this project requires:
- a docker network named `keepitsimple`
- Python 2.7
- the docker Python sdk (`pip install docker`)
- an environment variable `UPSTREAMS_LOCATION` with the file where the Nginx upstream will be written. `{project}` placeholder can be user and will be replaced by *keepitsimple*.
- the file designed by the previous environment variable owned by the user `gitlab-runner`
- an environment variable `DOCKER_NAMESPACE` with the namespace used for created production docker image 
- an environment variable `DEPLOY_SCRIPT` with the script which will be used to deploy the application. This script will receive `keepitsimple` as its first argument
- a gitlab-runner for the project on the production server:
```bash
$ sudo gitlab-runner register -n \
   --url https://gitlab.com/ \
   --registration-token MY_TOKEN \
   --executor shell \
   --description "My Runner for keepitsimple"
```

## Development usage
Start the containers:
```bash
$ make start
```
Note the first time you launch the containers, theme and node modules are installed. It can take a while. Use the following command to see the install progression:
```bash
$ make logs
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