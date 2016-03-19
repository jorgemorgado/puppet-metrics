# puppet-metrics

## Description

Everybody loves metrics. These ones are for Puppet. So, `puppet-metrics` is a
very simple set of tools and scripts to generate... Uhm, Puppet metrics ;-)

Spoiler alert: if you don't like surprises, don't run these against your
Puppet's code base. You might find things, you'd prefer to remain unknown.

## Dependencies

Install [sqlite](https://www.sqlite.org/):

```
# Red Hat
yum -y install sqlite

# Debian
aptitude -y install sqlite3
```

You also need to install the `cloc` package. To install it from sources, check
[here](https://github.com/AlDanial/cloc) or [here](http://cloc.sourceforge.net/).

And download the [D3.js](https://github.com/mbostock/d3/blob/master/d3.min.js)
library for data visualization in your browser.

## Usage

That's it! Check the `run-example.sh` script for a few examples of stats you
can generate. If you have more ideas just send me a pull request with your
"run script(s)".

## Preview

![Puppet Modules by Class LoC](https://raw.githubusercontent.com/wiki/jorgemorgado/puppet-metrics/modules_class_loc.png)

## Contributors

- [Jorge Morgado](https://github.com/jorgemorgado)

## License

Released under the [MIT License](http://www.opensource.org/licenses/MIT).
