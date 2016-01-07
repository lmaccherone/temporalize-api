var webpack = require('webpack');
var path = require('path');
var buildPath = path.resolve(__dirname, 'src/www');
var nodeModulesPath = path.resolve(__dirname, 'node_modules');
var HtmlWebpackPlugin = require('html-webpack-plugin');
var TransferWebpackPlugin = require('transfer-webpack-plugin');

var authString = process.env.TEMPORALIZE_USERNAME + ':' + process.env.TEMPORALIZE_PASSWORD;

var config = {
  //Entry point to the project
  entry: [
    'webpack/hot/dev-server',
    'webpack/hot/only-dev-server',
    path.join(__dirname, '/src/app/app.jsx')
  ],
  //Webpack config options on how to obtain modules
  resolve: {
    //When requiring, you don't need to add these extensions
    extensions: ["", ".js", ".jsx", ".md", ".txt", ".cjsx", ".coffee"],
    alias: {
      //material-ui requires will be searched in src folder, not in node_modules
      'material-ui/lib': path.resolve(__dirname, '../src'),
      'material-ui': path.resolve(__dirname, '../src'),
      //'files': "tzTime/files/index.js",
      //'tz': "raw!tzTime/files/tz"
    },
    //Modules will be searched for in these directories
    modulesDirectories: [
      "node_modules",
      path.resolve(__dirname, "node_modules"),
      path.resolve(__dirname, '../src'),
      path.resolve(__dirname, '../node_modules'),
      path.resolve(__dirname, 'src/app/components/raw-code'),
      path.resolve(__dirname, 'src/app/components/markdown')
    ]
  },
  //Configuration for dev server
  devServer: {
    contentBase: 'src/www',
    devtool: 'eval',
    hot: true,
    inline: true,
    port: 3000,
    proxy: {
      '/time-in-state*': {target: 'http://localhost:1338', secure: false},
      '/time-series*': {target: 'http://localhost:1338', secure: false},
      '/create-tenant*': {target: 'http://localhost:1338', secure: false},
      '/login*': {target: 'http://localhost:1338', secure: false},
      '/logout*': {target: 'http://localhost:1338', secure: false},
      '/hello*': {target: 'http://localhost:1338', secure: false}
    }
  },
  devtool: 'eval',
  //Output file config
  output: {
    path: buildPath,    //Path of output file
    filename: 'app.js'  //Name of output file
  },
  plugins: [
    //Used to include index.html in build folder
    new HtmlWebpackPlugin({
        inject: false,
        template: path.join(__dirname, '/src/www/index.html')
    }),
    //Allows for sync with browser while developing (like BorwserSync)
    new webpack.HotModuleReplacementPlugin(),
    //Allows error warninggs but does not stop compiling. Will remove when eslint is added
    new webpack.NoErrorsPlugin()
  ],
  externals: {
    fs: 'js', // To remove once https://github.com/benjamn/recast/pull/238 is released
  },
  module: {
        //eslint loader
        preLoaders: [
          {
            test: /\.(js|jsx)$/,
            loader: 'eslint-loader',
            include: [path.resolve(__dirname, "../src")],
            exclude: [path.resolve(__dirname, "../src/svg-icons"), path.resolve(__dirname, "../src/utils/modernizr.custom.js")]
          }
        ],
        //Allow loading of non-es5 js files.
        loaders: [
          {
            test: /\.jsx$/, //All .js and .jsx files
            loaders: ['react-hot','babel-loader?optional=runtime&stage=0'], //react-hot is like browser sync and babel loads jsx and es6-7
            include: [__dirname, path.resolve(__dirname, '../src')], //include these files
            exclude: [nodeModulesPath]  //exclude node_modules so that they are not all compiled
          },
          {
            test:/\.txt$/,
            loader: 'raw-loader',
            include: path.resolve(__dirname, 'src/app/components/raw-code')
          },
          {
            test:/\.md$/,
            loader: 'raw-loader',
            include: path.resolve(__dirname, 'src/app/components')
          },
          {
            test: /\.js$/, //All .js and .jsx files
            loader:'babel-loader?optional=runtime&stage=0', //react-hot is like browser sync and babel loads jsx and es6-7
            include: [__dirname, path.resolve(__dirname, '../src')], //include these files
            exclude: [nodeModulesPath]  //exclude node_modules so that they are not all compiled
          },
          {
            test: /\.css$/,
            loader: "style-loader!css-loader"
          },
          { test: /\.cjsx$/, loaders: ['coffee', 'cjsx']},
          { test: /\.coffee$/, loader: 'coffee' },
          //{
          //  test: /\.lzw$/,
          //  loader: "raw-loader",
          //  include: path.join(__dirname, 'node_modules', 'tzTime', 'files')
          //},
        ]
  },
  eslint: {
    configFile: '../.eslintrc'
  }
};

module.exports = config;
