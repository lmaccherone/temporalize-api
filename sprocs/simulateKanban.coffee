module.exports = (memo) ->

  randomPickerPackage = require('/Users/Larry/Dropbox/Projects/Lumenize/src/RandomPicker')  # TODO: Make this work with relative path or support path.join()
  RandomPicker = randomPickerPackage.RandomPicker

  unless memo?
    memo = {}
  unless memo.startDate?
    throw new Error('simulateKanban must be called with an object containing a `startDate` field (e.g. {startDate: "2015-01"})')
  unless memo.entitiesDesired?
    memo.entitiesDesired = 100

  memo.startDate = new Date(memo.startDate).toISOString()

  HIGHEST_DATE_STRING = '9999-01-01T00:00:00.000Z'
  LOWEST_DATE_STRING = '0001-01-01T00:00:00.000Z'

  possibleValues =
    ProjectHierarchy: [
      [1, 2, 3],
      [1, 2, 4],
      [1, 2],
      [5],
      [5, 6]
    ],
    Priority: [1, 2, 3, 4]
    Severity: [1, 2, 3, 4]
    Points: [null, 0.5, 1, 2, 3, 5, 8, 13]

    _TenantID: ['a']

  possibleStates = ['Backlog', 'Ready', 'In Progress', 'Accepted', 'Shipped']

  keys = (key for key, value of possibleValues)

  getIndex = (length) ->
    return Math.floor(Math.random() * length)

  getRandomValue = (fieldName) ->
    index = getIndex(possibleValues[fieldName].length)
    return possibleValues[fieldName][index]

  getRandomDocument = () ->
    document = {}
    for key in keys
      document[key] = getRandomValue(key)
    return document

  collection = getContext().getCollection()
  collectionLink = collection.getSelfLink()
  memo.stillQueueing = true
  memo.continuation = "Value does not matter"
  unless memo.wip?
    memo.wip = {}
    for state in possibleStates
      memo.wip[state] = 0
  today = new Date().toISOString()

  unless memo.entitiesCreated?
    memo.entitiesCreated = 0

  saveSnapshots = (callback) ->
    snapshot = memo.snapshots.shift()
    memo.stillQueueing = collection.createDocument(collectionLink, snapshot, (error, resource, options) ->
      if memo.snapshots.length > 0
        if memo.stillQueueing
          saveSnapshots(callback)
        else
          memo.continuation = 'value does not matter'
          callback()
      else
        delete memo.snapshots
        callback()
    )

  evolveEntity = () ->
    snapshots = []
    memo.currentDay = memo.startDate
    while not (memo.currentSnapshot.State is 'Shipped' or memo.currentDay >= today)
      entityID = memo.currentSnapshot._EntityID
      nextSnapshot = JSON.parse(JSON.stringify(memo.currentSnapshot))
      stateChanged = false
      switch memo.currentSnapshot.State
        when 'Backlog'
          if memo.wip.Ready < 10
            n = Math.random()
            if n < 0.2
              nextSnapshot.State = 'Ready'
              memo.wip.Ready++
              memo.wip.Backlog--
              stateChanged = true
        when 'Ready'
          if memo.wip['In Progress'] < 5
            n = Math.random()
            if n < 0.2
              nextSnapshot.State = 'In Progress'
              memo.wip['In Progress']++
              memo.wip['Ready']--
              stateChanged = true
        when 'In Progress'
          if memo.wip['Accepted'] < 10
            n = Math.random()
            if n < 0.15
              nextSnapshot.State = 'Accepted'
              memo.wip['Accepted']++
              memo.wip['In Progress']--
              stateChanged = true
        when 'Accepted'
          n = Math.random()
          if n < 0.1
            nextSnapshot.State = 'Shipped'
            memo.wip['Shipped']++
            memo.wip['Accepted']--
            stateChanged = true

      if stateChanged
        memo.currentSnapshot._ValidTo = memo.currentDay
        nextSnapshot._ValidFrom = memo.currentDay
        snapshots.push(memo.currentSnapshot)
        memo.currentSnapshot = nextSnapshot
      currentDayDateObject = new Date(memo.currentDay)
      nextDay = currentDayDateObject.valueOf() + 1000*60*60*24
      memo.currentDay = new Date(nextDay).toISOString()
      getContext().getResponse().setBody(memo)

    snapshots.push(nextSnapshot)
    getContext().getResponse().setBody(memo)
    return snapshots

  createEntity = () ->
    startDate = new Date(memo.startDate)
    creationDateString = new Date(startDate.valueOf() - Math.random() * 100 * 1000 * 60 * 60 * 24).toISOString()  # 100 days before

    snapshot = getRandomDocument()
    snapshot.State = 'Backlog'
    snapshot._ValidFrom = creationDateString
    snapshot._ValidTo = HIGHEST_DATE_STRING
    snapshot._EntityID = memo.entitiesCreated.toString()

    return snapshot

  createAndEvolveEntity = (callback) ->
    memo.currentSnapshot = createEntity()
    memo.wip.Backlog++
    memo.snapshots = evolveEntity()
    saveSnapshots(() ->
      memo.entitiesCreated++
      getContext().getResponse().setBody(memo)
      if memo.entitiesCreated < memo.entitiesDesired and memo.stillQueueing
        createAndEvolveEntity(callback)
      else
        memo.continuation = null
        delete memo.currentSnapshot
        return
    )

  createAndEvolveEntity()
