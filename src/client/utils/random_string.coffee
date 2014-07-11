randomString = exports.randomString = (length=0, special=false) ->
    ###
    Генерирует строку из случайных символов
    @param length: int длина генерируемой строки
    @param special: bool включать ли в строку спецсимволы
    ###
    iteration = 0
    randString = ""
    while iteration < length
        randomNumber = (Math.floor((Math.random() * 100)) % 94) + 33;
        if(!special)
            continue if ((randomNumber >=33) && (randomNumber <=47))
            continue if ((randomNumber >=58) && (randomNumber <=64))
            continue if ((randomNumber >=91) && (randomNumber <=96))
            continue if ((randomNumber >=123) && (randomNumber <=126))
        iteration++;
        randString += String.fromCharCode(randomNumber);
    return randString;
    
