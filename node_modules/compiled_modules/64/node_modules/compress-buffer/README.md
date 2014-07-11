# node-compress-buffer 

Synchronous zlib Buffer compression library for Node.js.


## Synopsis

```javascript
compress = require('compress-buffer').compress;
uncompress = require('compress-buffer').uncompress;

var rawData = fs.readFileSync("/etc/passwd");

var compressed   = compress(rawData);
var uncompressed = uncompress(compressed);

uncompressed == rawData // true!
```


## Why? 

For the sake of the KISS principle. Most of the time you don't need a streaming compression, you need to compress an existing and already complete data. 


## Options 

<code>compress()</code> takes two arguments: the data (must be a <code>Buffer()</code>) and optional compression level which must be within 1..9. It returns compressed <code>Buffer()</code> or <code>undefined</code> on error.

<code>uncompress()</code> takes a single argument: the data (must be a <code>Buffer()</code>) and returns uncompressed <code>Buffer()</code> or <code>undefined</code> on error.

Both functions could throw exceptions in the following cases:

* zlib initialisation fails;
* first argument is not a <code>Buffer</code> instance.


## Installation

	npm install compress-buffer

or

	npm install .


## License

See LICENSE file. Basically, it's a kind of "do-whatever-you-want-for-free" license.


## Thanks to 

* A lot of thanks for important suggestions goes to Konstantin Käfer who implemented a nice similar module node-zlib (https://github.com/kkaefer/node-zlib) earlier than me;
* Oleg Kertanov, pccowboy, addisonj, David Swift

## Author

Egor Egorov <me@egorfine.com>.

