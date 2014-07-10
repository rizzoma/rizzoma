{
  'targets': [
    {
      'target_name': 'node_stringprep',
      'cflags_cc!': [ '-fno-exceptions', '-fmax-errors=0' ],
      'include_dirs': [
        '<!(node -e "require(\'nan\')")'
      ],
      'conditions': [
        ['OS=="win"', {
          'conditions': [
            ['"<!@(cmd /C where /Q icu-config || echo n)"!="n"', {
              'sources': [ 'node-stringprep.cc' ],
              'cflags!': [ '-fno-exceptions', '`icu-config --cppflags`' ],
              'libraries': [ '`icu-config --ldflags`' ]
            }]
          ]
        }, { # OS != win
          'conditions': [
            ['"<!@(which icu-config > /dev/null || echo n)"!="n"', {
              'sources': [ 'node-stringprep.cc' ],
              'cflags!': [ '-fno-exceptions', '-fmax-errors=0', '`icu-config --cppflags`' ],
              'libraries': [ '`icu-config --ldflags`' ],
              'conditions': [
                ['OS=="freebsd"', {
                  'include_dirs': [
                      '/usr/local/include'
                  ],
                }],
                ['OS=="mac"', {
                  'include_dirs': [
                      '/opt/local/include'
                  ],
                  'xcode_settings': {
                    'GCC_ENABLE_CPP_EXCEPTIONS': 'YES'
                  }
                }]
              ]
            }]
          ]
        }]
      ]
     }
  ]
}
