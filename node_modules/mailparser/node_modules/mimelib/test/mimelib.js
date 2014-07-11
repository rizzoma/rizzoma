var testCase = require('nodeunit').testCase,
    mimelib = require("../index");

exports["Quoted printable"] = {
    "Encode short string": function(test){
        test.equal("Tere =D5=C4=D6=DC!", mimelib.encodeQuotedPrintable("Tere ÕÄÖÜ!", null, "Latin_1"));
        test.equal("Tere =C3=95=C3=84=C3=96=C3=9C=C5=A0=C5=BD!", mimelib.encodeQuotedPrintable("Tere ÕÄÖÜŠŽ!", null, "UTF-8"));
        test.equal("Tere =D0=DE!", mimelib.encodeQuotedPrintable("Tere ŠŽ!", null, "Win-1257"));
        test.done();
    },

    "Encode long string": function(test){
        var longLine = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"+
                       "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"+
                       "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"+
                       "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789",
            longLineEncoded = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLM=\r\n"+
                              "NOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ=\r\n"+
                              "abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklm=\r\n"+
                              "nopqrstuvwxyz0123456789";

        test.equal(longLineEncoded, mimelib.encodeQuotedPrintable(longLine));
        test.done();
    },

    "Wordwrap long string with UTF-8 sequence on edge": function(test){
        var longLine = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"+
                       "ABCDEFGHIÄÄÄPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"+
                       "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"+
                       "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789",
            longLineEncoded = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHI=\r\n"+
                              "=C3=84=C3=84=C3=84PQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJ=\r\n"+
                              "KLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVW=\r\n"+
                              "XYZabcdefghijklmnopqrstuvwxyz0123456789";
        test.equal(longLineEncoded, mimelib.encodeQuotedPrintable(longLine));
        test.done();
    },

    "Decode string": function(test){
        var longLine = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"+
                       "ABCDEFGHIÄÄÄPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"+
                       "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"+
                       "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789",
            longLineEncoded = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHI=\r\n"+
                              "=C3=84=C3=84=C3=84PQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJ=\r\n"+
                              "KLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVW=\r\n"+
                              "XYZabcdefghijklmnopqrstuvwxyz0123456789";

        test.equal(longLine, mimelib.decodeQuotedPrintable(longLineEncoded));
        test.done();
    },

    "Surrogate pair": function(test){
        // 💩 pile of poo
        test.equal("=F0=9F=92=A9", mimelib.encodeQuotedPrintable('\ud83d\udca9'))
        test.equal("\ud83d\udca9", mimelib.decodeQuotedPrintable('=F0=9F=92=A9'))
        test.done();
    }
}

exports["Base64"] = {
    "Convert string": function(test){
        test.equal("VGVyZSDVxNbcIQ==", mimelib.encodeBase64("Tere ÕÄÖÜ!", "Latin_1"));
        test.done();
    },

    "Decode string": function(test){
        test.equal("Tere ÕÄÖÜ!", mimelib.decodeBase64("VGVyZSDVxNbcIQ==", "Latin_1"));
        test.done();
    }
}

exports["Mime Words"] = {
    "Encode Mime Word QP": function(test){
        test.equal("=?ISO-8859-13?Q?J=F5ge-va=DE?=", mimelib.encodeMimeWord("Jõge-vaŽ", "Q", "iso-8859-13"));
        test.done();
    },

    "Decode Mime Word QP": function(test){
        test.equal("Jõge-vaŽ", mimelib.decodeMimeWord("=?ISO-8859-13?Q?J=F5ge-va=DE?="));
        test.done();
    },

    "Parse Mime Words": function(test){
        test.equal("Jõge-vaŽ zz Jõge-vaŽJõge-vaŽJõge-vaŽ", mimelib.parseMimeWords("=?ISO-8859-13?Q?J=F5ge-va=DE?= zz =?ISO-8859-13?Q?J=F5ge-va=DE?= =?ISO-8859-13?Q?J=F5ge-va=DE?= =?ISO-8859-13?Q?J=F5ge-va=DE?="))
        test.done();
    },

    "Split on maxLength QP": function(test){
        var inputStr = "Jõgeva Jõgeva Jõgeva mugeva Jõgeva Jõgeva Jõgeva Jõgeva Jõgeva",
            outputStr = "=?ISO-8859-1?Q?J=F5geva_J=F5gev?= =?ISO-8859-1?Q?a_J=F5geva?= mugeva =?ISO-8859-1?Q?J=F5geva_J=F5gev?= =?ISO-8859-1?Q?a_J=F5geva_J=F5g?= =?ISO-8859-1?Q?eva_J=F5geva?=",
            encoded = mimelib.encodeMimeWords(inputStr, "Q", 16, "ISO-8859-1");

        test.equal(outputStr, encoded)
        test.equal(inputStr, mimelib.parseMimeWords(encoded));
        test.done();
    },

    "Split on maxLength Base64": function(test){
        var inputStr = "Jõgeva Jõgeva Jõgeva mugeva Jõgeva Jõgeva Jõgeva Jõgeva Jõgeva",
            outputStr = "=?ISO-8859-1?B?SvVnZXZhIEr1Z2V2?= =?ISO-8859-1?B?YSBK9WdldmE=?= mugeva =?ISO-8859-1?B?SvVnZXZhIEr1Z2V2?= =?ISO-8859-1?B?YSBK9WdldmEgSvVn?= =?ISO-8859-1?B?ZXZhIEr1Z2V2YQ==?=",
            encoded = mimelib.encodeMimeWords(inputStr,"B", 16, "ISO-8859-1");

        test.equal(outputStr, encoded)
        test.equal(inputStr, mimelib.parseMimeWords(encoded));
        test.done();
    }
}

exports["Fold long line"] = function(test){
    var inputStr = "Subject: Testin command line kirja õkva kakva mõni tõnis kõllas põllas tõllas rõllas jušla kušla tušla musla",
        outputStr = "Subject: Testin command line kirja =?UTF-8?Q?=C3=B5kva?= kakva\r\n"+
                    " =?UTF-8?Q?m=C3=B5ni_t=C3=B5nis_k=C3=B5llas_p=C3=B5?=\r\n"+
                    " =?UTF-8?Q?llas_t=C3=B5llas_r=C3=B5llas_ju=C5=A1la_?=\r\n"+
                    " =?UTF-8?Q?ku=C5=A1la_tu=C5=A1la?= musla";

    test.equal(outputStr, mimelib.foldLine(mimelib.encodeMimeWords(inputStr, "Q", 52), 76, false, false, 52));
    test.done();
}