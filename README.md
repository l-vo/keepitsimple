# Keepitsimple

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

## Production deployment
The blog is deployed on Netlify by Github Actions when master branch is updated.