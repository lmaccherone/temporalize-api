path = require('path')
pbkdf2 = require(path.join(__dirname, '..', 'mixins', 'pbkdf2'))

exports.pbkdf2Test =

  pbkdf2Test: (test) ->

    password = "password"
    salt = "salt"
    actual = pbkdf2(password, salt, 1, 32)
    expected = 'Eg+2z/z4syxD5yJSVsT4N6hlSMkszDVICAWYfLcL4Xs='
    test.equal(actual, expected)

    actual = pbkdf2(password, salt, 2, 32)
    expected = 'rk0Mla9rRtMtCt/5KPBt0CowP47zwlHf1uLYWpVHTEM='
    test.equal(actual, expected)

    password = "passwordpasswordPASSWORD"
    salt = "saltSALTsalt"
    actual = pbkdf2(password, salt, 987, 32)
    expected = 'fHXpYZbWLW/JDF8yzDb2qNIawbhD/kXK6kewSvQhR+s='
    test.equal(actual, expected)

    test.done()

