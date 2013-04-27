fs = require 'fs'
http = require 'http'
util = require 'util'

# http://nodejs.org/api/all.json
NODEJS_API_OPTS =
  host: 'nodejs.org'
  port: 80
  path: '/api/all.json'
  method: 'GET'

DEFAULT_FILENAME = './NodeAPI_coffee.sublime-completions'

# simple function to download latest json api file and pass it to cb (callback)
downloadAPI = (cb) ->
  apistr = ''
  http.get NODEJS_API_OPTS, (res) =>
    res.on 'data', (data) ->
      # console.log data 
      apistr += data.toString()
    res.on 'end', ->
      fs.writeFileSync './node_api.json', apistr
      cb JSON.parse(apistr)

# parensType refers to whether you want to include parens around function arguments
# 0 = no, 1 = yes, 2 = add both with slightly different triggers
toCoffee = (nodeAPI, outFile, parensType=2) ->

  # Default filename
  outFile ?= DEFAULT_FILENAME

  # Simple sublime-completions format
  sublComps = 
    scope: 'source.coffee - variable.other.coffee'
    completions: []

  # Reusable api method to coffee completion converter (pushes to sublCompls instead of returning)
  convertMethod = (method, parent) ->
    if parent then base = "#{parent.name}.#{method.name}"
    else base = "#{method.name}"
    content = null
    if method.signatures?
      for signature in method.signatures
        lastContent = "#{content}"
        if signature.params?
          pi = 0 # Param index
          for param in signature.params
            if ++pi is 1 # incremement and check if first param
              if param.optional then content = "${#{pi}:# #{param.name}}"
              else content = "${#{pi}:#{param.name}}"
            else
              if param.optional then content += "${#{pi}:, ${#{++pi}:##{param.name}}}"
              else content += ", ${#{pi}:#{param.name}}"
        else 
          content = ''
        if content isnt lastContent
          if content isnt null
            if parensType in [0, 2]
              sublComps.completions.push
                trigger: "#{base}"
                contents: "#{base} #{content}"
            if parensType in [1, 2]
              sublComps.completions.push
                trigger: "#{base}("
                contents: "#{base}(#{content})"
          else
            sublComps.completions.push
              trigger: "#{base}"
              contents: "#{base}()"

  # convert module to require call
  convertModule = (module) ->
    sublComps.completions.push
      trigger: "#{module.name}"
      contents: "#{module.name} = require '#{module.name}'"

  # Loop through each global
  for global in nodeAPI.globals
    if global.methods?
      for method in global.methods
        convertMethod method, global

  # Loop through each var
  for variable in nodeAPI.vars
    if variable.methods?
      for method in variable.methods
        convertMethod method, variable
    else
      sublComps.completions.push "#{variable.name}"

  # Loop through each standalone method
  for method in nodeAPI.methods
    convertMethod method

  # Loop through each module
  for module in nodeAPI.modules
    if module.methods?
      sublComps.completions.push 
        trigger: "#{module.name}"
        contents: "#{module.name} = require '#{module.name}'"
      for method in module.methods
        convertMethod method, module
    if module.vars?
      for variable in module.vars
        if variable.methods?
          for method in variable.methods
            convertMethod method, module
        if variable.properties?
          for property in variable.properties
            sublComps.completions.push "#{module.name}.#{property.name}"
    if module.classes?
      for clas in module.classes 
        sublComps.completions.push "#{clas.name}"
        if clas.methods?
          for method in clas.methods
            alias = /(\w+)\.\w+\(.*\)/.exec method.textRaw
            if alias 
              convertMethod method, { name: "#{alias[1]}" }
            else
              convertMethod method, clas
        if clas.properties?
          for property in variable.properties
            sublComps.completions.push "#{clas.name}.#{property.name}"

  # Write the completions object as json
  fs.writeFileSync(outFile, JSON.stringify(sublComps))

  # Log it in case they wanna copy and paste??
  console.log JSON.stringify(sublComps)

downloadAPI (napi) ->
  toCoffee napi

