# flarum-docker-compose

A docker-compose.yml for flarum

## 使用方法

1. 复制一份 `.env.sample` 文件命名为 `.env`。

2. 修改 `.env` 里的内容。

3. `docker-compose up -d` 启动一个新的 flarum 网站。

### Install an extension

```sh
docker-compose exec flarum extension require some/extension
```

### Remove an extension

```sh
docker-compose exec flarum extension remove some/extension
```

### List all extensions

```sh
docker-compose exec flarum extension list
```

### Updating your database and removing old assets & extensions

```sh
docker-compose exec flarum php /flarum/app/flarum migrate
docker-compose exec flarum php /flarum/app/flarum cache:clear
```

### More commands

```sh
docker-compose exec flarum php /flarum/app/flarum --help
docker-compose exec flarum php /flarum/app/flarum info
```

### Upgrade

```sh
docker-compose exec flarum composer update --prefer-dist --no-plugins --no-dev -a --with-all-dependencies -d /flarum/app/ \
&& docker-compose exec flarum php /flarum/app/flarum migrate \
&& docker-compose exec flarum php /flarum/app/flarum cache:clear
```

### Crontab

```sh
* * * * * cd /path-to-your-project && /usr/local/bin/docker-compose exec -T flarum php /flarum/app/flarum schedule:run >> /dev/null 2>&1
```

## Related

- [flarum/flarum](https://github.com/flarum/flarum) - Simple forum software for building great communities.
- [flarum/core](https://github.com/flarum/core) - Simple forum software for building great communities.
- [docker-flarum](https://github.com/mondediefr/docker-flarum) - 💬 🐳 Docker image of Flarum

## License

Copyright (c) 2021 [Pipecraft][my-url]. Licensed under the [MIT license][license-url].

## >\_

[![Pipecraft](https://img.shields.io/badge/https://-pipecraft.net-brightgreen)](https://www.pipecraft.net)
[![BestXTools](https://img.shields.io/badge/https://-bestxtools.com-brightgreen)](https://www.bestxtools.com)
[![PZWD](https://img.shields.io/badge/https://-pzwd.net-brightgreen)](https://pzwd.net)

[my-url]: https://www.pipecraft.net
[license-url]: LICENSE
