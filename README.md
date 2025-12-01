# O3SR - One-on-one Server Relay

O3SR is a Ruby gem implementing a network multiplexing relay system that enables efficient connection pooling and load distribution across multiple relay servers. It provides a three-tier architecture for routing client connections through a central matcher to available relay servers.

## Overview

O3SR consists of three main components working together to create a robust network relay system:

- **Matcher**: Central hub that accepts relay and client connections, routing traffic between them
- **Client/Relay**: Proxy component that connects to the matcher and forwards traffic to destination servers
- **Protocol**: Binary message protocol for efficient communication between components

### Architecture

```
Client → Matcher → Relay → Destination Server
```

The system uses non-blocking I/O with `IO.select()` for efficient connection multiplexing, allowing a single process to handle multiple concurrent connections.

## Installation

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add o3sr
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install o3sr
```

Or install directly from the repository:

```bash
git clone https://github.com/basking2/o3sr.git
cd o3sr
bin/setup
```

Or using docker:

```bash
docker build -t o3sr .
```

## Usage

O3SR provides a command-line tool `o3sr` for running matcher and client/relay components.

### Running a Matcher

The matcher acts as the central hub, listening on two ports:
- Port 6543: For relay connections
- Port 6544: For client connections

```bash
# Run matcher with default ports
o3sr --matcher

# Run matcher with custom ports
o3sr --matcher --relay-port 7000 --client-port 7001
```

### Running a Client/Relay

The client/relay connects to a matcher and proxies connections to a destination server:

```bash
# Connect to local matcher, proxy to localhost:80
o3sr --client

# Connect to remote matcher, proxy to different destination
o3sr --client --matcher-host 192.168.1.100 --dest-host example.com --dest-port 8080
```

### Running in Docker

```
docker run --rm -it -v "$HOME/.config/o3sr/config.yml:/o3sr/config.yml" o3sr
```

### Configuration File

O3SR supports YAML configuration files for easier deployment. Create a config file at:
- `~/.config/o3sr/config.yml` (XDG standard)
- `~/.o3sr.yml` (legacy fallback)

```yaml
# Example config.yml
mode: client
matcher_host: "relay.example.com"
matcher_port: 6543
dest_host: "backend.internal"
dest_port: 3000
```

### Command Line Options

```
Usage: o3sr [options]

O3SR (One-on-one Server Relay) - Network multiplexing relay system

Modes:
  -m, --matcher                    Run as matcher (central hub)
  -c, --client                     Run as client/relay proxy

Matcher options:
      --relay-port PORT            Port for relay connections (default: 6543)
      --client-port PORT           Port for client connections (default: 6544)

Client options:
      --matcher-host HOST          Matcher host to connect to (default: localhost)
      --matcher-port PORT          Matcher port to connect to (default: 6543)
      --dest-host HOST             Destination host for proxied connections (default: localhost)
      --dest-port PORT             Destination port for proxied connections (default: 80)

General options:
  -h, --help                       Show this help message
  -v, --version                    Show version
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

### Setup

```bash
# Install dependencies
bin/setup

# Interactive console for experimenting
bin/console
```

### Testing

```bash
# Run all tests
rake spec

# Run specific test file
bundle exec rspec spec/o3sr_proto_spec.rb

# Run tests with documentation format (configured in .rspec)
bundle exec rspec
```

### Code Quality

```bash
# Run RuboCop linter
rake rubocop

# Run both tests and linting (default rake task)
rake
```

### Gem Management

```bash
# Install gem locally for testing
bundle exec rake install

# Build gem package
bundle exec rake build

# Release new version (updates version.rb, creates git tag, pushes to rubygems)
bundle exec rake release
```

## Technical Details

### Protocol

O3SR uses a custom binary protocol for efficient communication:

- **4-byte header**: version, id, type, data_length
- **Variable data**: message payload (max 1,024,000 bytes)
- **Message types**: CONNECT (1), DISCONNECT (2), TRAFFIC (3)

### Components

#### Matcher (`lib/o3sr/matcher.rb`)
- Listens on dual ports (6543 for relays, 6544 for clients)
- Maintains connection pools and routing logic
- Random distribution of clients to available relays

#### Client/Relay (`lib/o3sr/client.rb`)
- Bidirectional proxy between matcher and destination servers
- On-demand connection creation to destination servers
- Protocol translation between raw TCP and framed messages

#### Protocol Layer (`lib/o3sr/proto.rb`)
- Message serialization and parsing
- Partial message buffering for incomplete reads
- Binary format using network byte order

### Requirements

- Ruby >= 3.1.0
- No external dependencies (pure Ruby implementation)

## Use Cases

O3SR is particularly useful for:

- **Load balancing**: Distribute client connections across multiple backend servers
- **Connection pooling**: Reduce connection overhead by reusing relay connections
- **Network traversal**: Route connections through intermediary servers
- **Service mesh**: Create a lightweight service communication layer
- **Development proxying**: Route development traffic through staging environments

## Example Deployment

### Simple Load Balancer

1. **Start matcher on load balancer server:**
```bash
o3sr --matcher --relay-port 6543 --client-port 6544
```

2. **Start relays on backend servers:**
```bash
# On server 1
o3sr --client --matcher-host loadbalancer.example.com --dest-host localhost --dest-port 3000

# On server 2
o3sr --client --matcher-host loadbalancer.example.com --dest-host localhost --dest-port 3000
```

3. **Connect clients to port 6544 on the load balancer**

### Multi-tier Architecture

For more complex setups, you can chain multiple O3SR instances to create multi-tier routing architectures.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/basking2/o3sr.

### Development Workflow

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/my-new-feature`)
3. Make your changes and add tests
4. Run the test suite (`rake spec`)
5. Run the linter (`rake rubocop`)
6. Commit your changes (`git commit -am 'Add some feature'`)
7. Push to the branch (`git push origin feature/my-new-feature`)
8. Create a Pull Request

### Code Style

- Follow Ruby community conventions
- Use double quotes for string literals (enforced by RuboCop)
- Include frozen string literal pragma in all files
- Add tests for new functionality
- Update documentation as needed

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Version History

- **0.1.0** - Initial release with core functionality
  - Matcher component with dual-port architecture
  - Client/relay proxy with on-demand connections
  - Binary message protocol with framing
  - Command-line interface with configuration support
