# Zekrom 
Zekrom is a migration tool, inspired by [goose](https://github.com/pressly/goose).
Developed for gain experience in zig and sql stuff, it's a work in progress.
for now it's only supports sqlite3 but in future maybe other dbs.

## Usage
Fow now there is 3 ways to interact with Zekrom:

*Migrate to a latest version:*
```bash
$ zekrom migrate
```

*Migrate to a specific version:*
```bash
$ zekrom migrate 1
```

*Rollback to a specific version:*
```bash
$ zekrom drop_to 2
```

## Future plans
- support more databases
- docker image 
- more in [todo](./TODO.md)
