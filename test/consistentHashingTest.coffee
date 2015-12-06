ConsistentHashing = require('consistent-hashing');
documentdb = require('documentdb')
countingArray = require('../src/countingArray')

exports.consistentHashingTest =

  npmModuleTest: (test) ->
    totalCount = 1000
    for i in [2..5]
      collectionResolver = new ConsistentHashing(countingArray(i + 1))
      oldCollectionResolver = new ConsistentHashing(countingArray(i))
      movedCount = 0
      for j in [1..totalCount]
        guid = documentdb.Base.generateGuidId()
        if collectionResolver.getNode(guid) isnt oldCollectionResolver.getNode(guid)
          movedCount++

      portionMoved = movedCount / totalCount
      expected =  1 / (i + 1)
      error = expected * 0.17
      test.ok(expected - error < portionMoved < expected + error)

    test.done()