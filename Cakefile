fs = require('fs')
spawnSync = require('child_process').spawnSync
path = require('path')
{_} = require('documentdb-utils')

endsWith = (s, suffix) ->
  s.indexOf(suffix, s.length - suffix.length) isnt -1

runSync = (command, options, next) ->
  {stderr, stdout} = runSyncRaw(command, options)
  if stderr?.length > 0
    console.error("Error running `#{command}`\n" + stderr)
    process.exit(1)
  if next?
    next(stdout)
  else
    if stdout?.length > 0
      console.log("Stdout running command '#{command}'...\n" + stdout)

runSyncNoExit = (command, options = []) ->
  {stderr, stdout} = runSyncRaw(command, options)
  console.log("Output of running '#{command + ' ' + options.join(' ')}'...\n#{stderr}\n#{stdout}\n")
  return {stderr, stdout}

runSyncRaw = (command, options) ->
  output = spawnSync(command, options)
  stdout = output.stdout?.toString()
  stderr = output.stderr?.toString()
  return {stderr, stdout}

task('watch', 'Uses nodemon to restart server every time it senses a file change', () ->
  process.chdir(__dirname)
  console.log('Just run `nodemon`.')
)

task('compile', 'Compile CoffeeScript source files to JavaScript', () ->
  process.chdir(__dirname)
  folders = ['.', 'src']
  for folder in folders
    pathToCompile = path.join(__dirname, folder)
    contents = fs.readdirSync(pathToCompile)
    files = ("#{file}" for file in contents when (file.indexOf('.coffee') > 0))
    files = (path.join(folder, file) for file in files)
    runSync(path.join(__dirname, 'node_modules', '.bin', 'coffee'), ['-c'].concat(files))
)

task('clean', 'Deletes .js and .map files', () ->
  folders = ['.', 'src']
  for folder in folders
    pathToClean = path.join(__dirname, folder)
    contents = fs.readdirSync(pathToClean)
    for file in contents when (_.endsWith(file, '.js') or _.endsWith(file, '.map')) and not _.endsWith(file, 'server.js')
      fs.unlinkSync(path.join(pathToClean, file))
)

task('publish', 'Publish to npm and add git tags', () ->
  console.log('compiling CoffeeScript')
  process.chdir(__dirname)
  runSync('cake', ['compile'])

  # !TODO: generate docs

  console.log('checking git status --porcelain')
  runSync('git', ['status', '--porcelain'], (stdout) ->
    if stdout.length is 0
      console.log('checking origin/master')
      {stderr, stdout} = runSyncNoExit('git', ['rev-parse', 'origin/master'])
      console.log('checking master')
      stdoutOrigin = stdout
      {stderr, stdout} = runSyncNoExit('git', ['rev-parse', 'master'])
      stdoutMaster = stdout

      if stdoutOrigin == stdoutMaster

        console.log('running npm publish')
        runSyncNoExit('npm', ['publish', '.'])

        if fs.existsSync('npm-debug.log')
          console.error('`npm publish` failed. See npm-debug.log for details.')
        else

          console.log('creating git tag')
          runSyncNoExit("git", ["tag", "v#{require('./package.json').version}"])
          runSyncNoExit("git", ["push", "--tags"])
      else
        console.error('Origin and master out of sync. Not publishing.')
    else
      console.error('`git status --porcelain` was not clean. Not publishing.')
  )
  runSync('cake', ['clean'])
)
