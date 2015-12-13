module.exports = (memo) ->

  randomPickerPackage = require('/Users/Larry/Dropbox/Projects/Lumenize/src/RandomPicker')  # TODO: Make this work with relative path or support path.join()
  RandomPicker = randomPickerPackage.RandomPicker

  unless memo?
    memo = {}
  unless memo.startDate?
    throw new Error('simulateKanban must be called with an object containing a `startDate` field (e.g. {startDate: "2015-01"})')
  unless memo.entitiesDesired?
    memo.entitiesDesired = 1000

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

    _TenantID: ['test-tenant']

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
  memo.stillQueueingEvolution = true
  memo.continuation = "Value does not matter"
  memo.wip = {}
  for state in possibleStates
    memo.wip[state] = 0
  today = new Date().toISOString()
  memo.seedSnapshots = {}

  memo.entitiesCreated = 0

  upsertEntity = (snapshot, callback) ->

    callback()
    # be sure to return last still queing
    return true

  evolveEntity = (callback) ->
    entityID = memo.currentSnapshot._EntityID
    stateChanged = false
    switch memo.currentSnapshot.State
      when 'Backlog'
        if memo.wip.Ready < 10
          n = Math.random()
          if n < 0.2
            memo.currentSnapshot.State = 'Ready'
            memo.wip.Ready++
            memo.wip.Backlog--
            stateChanged = true
      when 'Ready'
        if memo.wip['In Progress'] < 5
          n = Math.random()
          if n < 0.3
            memo.currentSnapshot.State = 'In Progress'
            memo.wip['In Progress']++
            memo.wip['Ready']--
            stateChanged = true
      when 'In Progress'
        if memo.wip['Accepted'] < 10
          n = Math.random()
          if n < 0.1
            memo.currentSnapshot.State = 'Accepted'
            memo.wip['Accepted']++
            memo.wip['In Progress']--
            stateChanged = true
      when 'Accepted'
        n = Math.random()
        if n < 0.3
          memo.currentSnapshot.State = 'Shipped'
          memo.wip['Shipped']++
          memo.wip['Accepted']--
          stateChanged = true
          console.log("Shipped entity #{entityID} on #{memo.currentDay}")

    if stateChanged
      memo.stillQueueingEvolution = upsertEntity(memo.currentSnapshot, (error, resource, options) ->
        if error?
          throw new Error(error)
        if memo.stillQueueingEvolution
          currentDayDateObject = new Date(memo.currentDay)
          nextDay = currentDayDateObject.valueOf() + 1000*60*60*24
          getContext().getResponse().setBody(memo)
          memo.currentDay = new Date(nextDay).toISOString()
          if memo.currentSnapshot.State is 'Shipped' or memo.currentDay >= today
            callback(null)
            return
          else if memo.stillQueueingEvolution
            evolveEntity(callback)
            return
          else
            callback("Did't finish evolving")
            return
      )
    else
      if memo.stillQueueingEvolution
        currentDayDateObject = new Date(memo.currentDay)
        nextDay = currentDayDateObject.valueOf() + 1000*60*60*24
        getContext().getResponse().setBody(memo)
        memo.currentDay = new Date(nextDay).toISOString()
        if memo.currentSnapshot.State is 'Shipped' or memo.currentDay >= today
          callback(null)
          return
        else if memo.stillQueueingEvolution
          evolveEntity(callback)
          return
      else
        memo.continuation = 'value does not matter'
        callback("Did't finish evolving")
#        return

  createEntities = (callback) ->
    if memo.entitiesCreated < memo.entitiesDesired and memo.stillQueueing
      startDate = new Date(memo.startDate)
      creationDateString = new Date(startDate.valueOf() - Math.random() * 100 * 1000 * 60 * 60 * 24).toISOString()  # 100 days before

      snapshot = getRandomDocument()
      snapshot.State = 'Backlog'
      snapshot._ValidFrom = creationDateString
      snapshot._ValidTo = HIGHEST_DATE_STRING
      snapshot._EntityID = memo.entitiesCreated.toString()

      memo.example = snapshot

      memo.stillQueueing = collection.createDocument(collectionLink, snapshot, (error, resource, options) ->
        if error?
          throw new Error(error)
        else if memo.stillQueueing
          unless memo.firstSnapshot?
            memo.firstSnapshot = snapshot
          memo.wip['Backlog']++
          memo.currentSnapshot = snapshot
          memo.currentDay = memo.startDate
          memo.entitiesCreated++
          memo.seedSnapshots[snapshot._EntityID] = snapshot
          createEntities(callback)
        else
          memo.continuation = null
          getContext().getResponse().setBody(memo)
          callback()

      )
    else
      if memo.stillQueueing
        memo.continuation = null
        callback()
      else
        memo.continuation = 'Value does not matter'
        getContext().getResponse().setBody(memo)
        return

  evolveEntities = (callback) ->
    evolveEntity((err) ->
      memo.entitiesEvolved++
      if memo.entitiesEvolved < memo.entitiesDesired
        nextEntityID = (Number(memo.currentSnapshot._EntityID) + 1).toString()
        memo.currentSnapshot = memo.seedSnapshots[nextEntityID]
        memo.currentDay = memo.startDate
        return evolveEntities(callback)
      else
        return callback()
    )


  createEntities((err) ->
    console.log('done creating entities')
    memo.currentSnapshot = memo.firstSnapshot
    memo.currentDay = memo.startDate
    memo.entitiesEvolved = 0
    evolveEntities((err) ->
      console.log('done evolving entities')
    )
  )
