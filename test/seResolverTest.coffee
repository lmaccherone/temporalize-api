# TODO: refactor to get rid of requirement to have live DocumentDB. Would require making some methods static.
path = require('path')
StorageEngine = require(path.join('..', 'src', 'StorageEngine'))
{getLink, WrappedClient} = require('documentdb-utils')

config =
  firstTopLevelID: 'dev-test-database'
  firstSecondLevelID: 'dev-test-collection'
  refreshConfigMS: 10000
  terminate: true
  cacheSelfLinks: false
  debug: false

se = null
client = null

exports.resolverAndLinkTest =

  theTest: (test) ->

    se = new StorageEngine(config, false, (err, se) ->
      expected = ['dbs/dev-test-database/colls/dev-test-collection']
      test.deepEqual(se._resolveToListOfPartitions(), expected)
      test.deepEqual(se._resolveToListOfPartitions('anything'), expected)
      test.deepEqual(se._resolveToListOfPartitions('anything', 'something'), expected)

      partitionConfig =
        topLevelPartitions:
          'first':
            id: 'first',
            secondLevelPartitions:
              '0': {id: '0'}
              '1': {id: '1'}
              '2': {id: '2'}
          'second':
            id: 'second',
            secondLevelPartitions:
              'a': {id: 'a'}
              'b': {id: 'b'}
              'c': {id: 'c'}
        topLevelLookupMap: {'default': 'first', 'key-customer': 'second'}

      expected = ['dbs/first/colls/0', 'dbs/first/colls/1', 'dbs/first/colls/2', 'dbs/second/colls/a', 'dbs/second/colls/b', 'dbs/second/colls/c', ]
      test.deepEqual(se._resolveToListOfPartitions(null, null, partitionConfig), expected)
      expected = ['dbs/first/colls/0', 'dbs/first/colls/1', 'dbs/first/colls/2']
      test.deepEqual(se._resolveToListOfPartitions('anything', null, partitionConfig), expected)
      expected = ['dbs/second/colls/a', 'dbs/second/colls/b', 'dbs/second/colls/c', ]
      test.deepEqual(se._resolveToListOfPartitions('key-customer', null, partitionConfig), expected)

      expected = ['dbs/first/colls/0']
      test.deepEqual(se._resolveToListOfPartitions('anything', 'C', partitionConfig), expected)
      expected = ['dbs/first/colls/1']
      test.deepEqual(se._resolveToListOfPartitions('anything', 'B', partitionConfig), expected)
      expected = ['dbs/first/colls/2']
      test.deepEqual(se._resolveToListOfPartitions('anything', 'A', partitionConfig), expected)

      expected = ['dbs/second/colls/a']
      test.deepEqual(se._resolveToListOfPartitions('key-customer', 'C', partitionConfig), expected)
      expected = ['dbs/second/colls/b']
      test.deepEqual(se._resolveToListOfPartitions('key-customer', 'J', partitionConfig), expected)
      expected = ['dbs/second/colls/c']
      test.deepEqual(se._resolveToListOfPartitions('key-customer', 'E', partitionConfig), expected)

      partitionConfig =
        topLevelPartitions:
          'first':
            id: 'first',
            secondLevelPartitions:
              '0': {id: '0', weight: 200}
              '1': {id: '1', weight: 200}
              '2': {id: '2', weight: 200}
        topLevelLookupMap: {'default': 'first'}

      expected = ['dbs/first/colls/0']
      test.deepEqual(se._resolveToListOfPartitions('anything', 'C', partitionConfig), expected)
      expected = ['dbs/first/colls/1']
      test.deepEqual(se._resolveToListOfPartitions('anything', 'B', partitionConfig), expected)
      expected = ['dbs/first/colls/2']
      test.deepEqual(se._resolveToListOfPartitions('anything', 'A', partitionConfig), expected)

      partitionConfig =
        topLevelPartitions:
          'first':
            id: 'first',
            secondLevelPartitions:
              '0': {id: '0', weight: 200}
              '1': {id: '1', weight: 300}
              '2': {id: '2', weight: 400}
        topLevelLookupMap: {'default': 'first'}

      expected = ['dbs/first/colls/2']
      test.deepEqual(se._resolveToListOfPartitions('anything', 'C', partitionConfig), expected)
      expected = ['dbs/first/colls/2']
      test.deepEqual(se._resolveToListOfPartitions('anything', 'B', partitionConfig), expected)
      expected = ['dbs/first/colls/2']
      test.deepEqual(se._resolveToListOfPartitions('anything', 'A', partitionConfig), expected)
      expected = ['dbs/first/colls/0']
      test.deepEqual(se._resolveToListOfPartitions('anything', 'D', partitionConfig), expected)
      expected = ['dbs/first/colls/0']
      test.deepEqual(se._resolveToListOfPartitions('anything', 'E', partitionConfig), expected)
      expected = ['dbs/first/colls/2']
      test.deepEqual(se._resolveToListOfPartitions('anything', 'F', partitionConfig), expected)
      expected = ['dbs/first/colls/1']
      test.deepEqual(se._resolveToListOfPartitions('anything', 'G', partitionConfig), expected)
      expected = ['dbs/first/colls/2']
      test.deepEqual(se._resolveToListOfPartitions('anything', 'H', partitionConfig), expected)
      expected = ['dbs/first/colls/1']
      test.deepEqual(se._resolveToListOfPartitions('anything', 'I', partitionConfig), expected)

      console.log('all tests finished running')

      test.done()
    )