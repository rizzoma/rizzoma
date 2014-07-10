{
	"targets": [
		{
			"target_name": "compress_buffer_bindings",
			"sources": [ "src/compress-buffer.cc" ],
			"dependencies": [
			    "deps/zlib/zlib.gyp:zlib"
			]
		}
	]
}
