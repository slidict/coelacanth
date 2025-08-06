# coelacanth

[![Gem Version](https://badge.fury.io/rb/coelacanth.svg)](https://badge.fury.io/rb/coelacanth)
[![Build Status](https://github.com/slidict/coelacanth/actions/workflows/main.yml/badge.svg)](https://github.com/slidict/coelacanth/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

`coelacanth` is a gem that allows you to parse and analyze web pages, extracting key statistics and information for further use within your projects.

## Installation

Add this line to your application's Gemfile:


```ruby
gem 'coelacanth'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install coelacanth
```

### Resolving UID Mismatch Between Docker and Host

To resolve issues related to the difference between Docker's UID and the host's UID, add the following line to your .bashrc or similar shell configuration file:

```bash
export UID=${UID}
```

This will ensure that the environment variable UID is correctly set in your Docker containers, matching your host system's user ID.

This explanation provides clear instructions on how to resolve the UID mismatch issue using the export command.

## Usage
To use coelacanth, first require it.

```ruby
require 'coelacanth'
```

Then, you can easily parse and extract information from a web page like this:

```ruby
url = "https://example.com"
stats = Coelacanth.analyze(url)
puts stats[:title]
```

- rspec

```
$ bundle exec rspec
```

## Features
- Get dom by oga
- Get screenshot
- Get page title

## Commit Message Guidelines

To ensure consistency and facilitate automatic updates to the `CHANGELOG.md`, please follow the [Conventional Commits](https://www.conventionalcommits.org/) specification when creating commit messages. This helps maintain a clear and structured commit history.

When submitting a Pull Request (PR), make sure your commits adhere to these guidelines.

### Example of Conventional Commit Messages:

- `feat: add new feature for parsing web pages`
- `fix: resolve issue with URL redirection`
- `docs: update README with usage instructions`
- `chore: update dependencies`
- `build: update build configuration`
- `ci: update CI pipeline`
- `style: fix code style issues`
- `refactor: refactor code for better readability`
- `perf: improve performance of data processing`
- `test: add new tests for URL parsing module`

By following these guidelines, you help ensure that our project's commit history is easy to navigate and that versioning and release notes are generated correctly.

## Contributing
Bug reports and pull requests are welcome on GitHub at https://github.com/slidict/coelacanth. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the Contributor Covenant code of conduct.

## License
The gem is available as open-source under the terms of the MIT License.

## Acknowledgments
Special thanks to all the contributors and open-source projects that make this possible.
