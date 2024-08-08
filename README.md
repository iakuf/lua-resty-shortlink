# Lua Shortlink Service for OpenResty

This Lua module provides a URL shortening service for OpenResty, integrated with Redis for storage. It offers a flexible and reusable solution by allowing the target redirection domain to be configured dynamically.

## Features

- **Short URL Creation**: Generates short URLs for given long URLs and stores them in Redis.
- **Redirect Service**: Redirects short URLs to their corresponding long URLs with a 302 HTTP status code.
- **Automatic Duplicate Detection**: Returns an existing short URL if the same long URL is submitted again.
- **Configurable Domain**: The redirection domain can be dynamically configured through the module's initialization.

## Requirements

- OpenResty
- Redis
- LuaJIT

## Installation

To install this module, you can use the OpenResty Package Manager (opm):

```
opm get iakuf/lua-resty-shortlink
```

## Configuration

In your `nginx.conf`:

```
http {
    
    init_by_lua_block {
        local shortlink = require "shortlink"
        shortlink.init({
            host = "127.0.0.1",
            port = 6379,
            timeout = 1000,
            domain = "http://yourdomain.com"  -- Set your desired redirection domain here
        })
    }

    server {
        listen 80;

        location /create {
            content_by_lua_block {
                local shortlink = require "shortlink"
                shortlink.create()
            }
        }

        location /s/ {
            content_by_lua_block {
                local shortlink = require "shortlink"
                shortlink.redirect()
            }
        }
    }
}
```

### Configuration Options

- `host`: Redis server hostname (default: `127.0.0.1`)
- `port`: Redis server port (default: `6379`)
- `timeout`: Redis connection timeout in milliseconds (default: `1000`)
- `domain`: The domain used for generating short links (default: `"http://yourdomain.com"`)

## API Endpoints

### POST `/create`

Create a new short URL.

#### Request Body

```
{
    "url": "http://example.com/very/long/url",
    "expiry": 3600  // Expiry time in seconds
}
```

#### Response

```
{
    "short_link": "http://yourdomain.com/s/abc123"
}
```

- Returns an existing short link if the URL has already been shortened.

### GET `/s/:short_link`

Redirect to the original URL associated with the provided short link.

- Example: Accessing `http://yourdomain.com/s/abc123` will redirect to `http://example.com/very/long/url`.

## Example Usage

You can use `curl` to test the service:

### Create a Short Link

```
curl -X POST http://localhost:8080/create -d '{"url": "http://example.com", "expiry": 3600}'
```

### Access the Short Link

```
curl -i http://localhost:8080/s/abc123
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Contributions are welcome! Please fork the repository and submit a pull request.

## Acknowledgments

- Built with [OpenResty](https://openresty.org) and [Redis](https://redis.io).
- Inspired by the need for efficient and scalable URL shortening services.
