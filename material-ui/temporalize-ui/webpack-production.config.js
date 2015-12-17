var webpack = require('webpack');
var path = require('path');
var buildPath = path.resolve(__dirname, 'build');
var nodeModulesPath = path.resolve(__dirname, 'node_modules');
var HtmlWebpackPlugin = require('html-webpack-plugin');
var TransferWebpackPlugin = require('transfer-webpack-plugin');

var config = {
  //Entry point to the project
  entry: [
    path.join(__dirname, '/src/app/app.jsx')
  ],
  //Webpack config options on how to obtain modules
  resolve: {
    //When requiring, you don't need to add these extensions
    extensions: ["", ".js", ".jsx", ".md", ".txt"],
    alias: {
      //material-ui requires will be searched in src folder, not in node_modules
      'material-ui/lib': path.resolve(__dirname, '../src'),
      'material-ui': path.resolve(__dirname, '../src'),
    },
    //Modules will be searched for in these directories
    modulesDirectories: [
      "web_modules",
      "node_modules",
      path.resolve(__dirname, "node_modules"),
      path.resolve(__dirname, '../src'),
      path.resolve(__dirname, '../node_modules'),
      path.resolve(__dirname, 'src/app/components/raw-code'),
      path.resolve(__dirname, 'src/app/components/markdown')
    ]
  },
  devtool: 'source-map',
  //Configuration for server
  devServer: {
    contentBase: 'build'
  },
  //Output file config
  output: {
    path: buildPath,    //Path of output file
    filename: 'app.js'  //Name of output file
  },
  plugins: [
    //Used to include index.html in build folder
    new webpack.optimize.UglifyJsPlugin({
      compress: {
        warnings: false
      }
    }),
    new webpack.DefinePlugin({
      "process.env": {
        NODE_ENV: JSON.stringify("production")
      }
    }),
    new HtmlWebpackPlugin({
        inject: false,
        template: path.join(__dirname, '/src/www/index.html')
    }),
    //Allows error warninggs but does not stop compiling. Will remove when eslint is added
    new webpack.NoErrorsPlugin(),
    //Transfer Files
    new TransferWebpackPlugin([
      {from: 'www/css', to: 'css'},
      {from: 'www/images', to: 'images'}
    ], path.resolve(__dirname,"src"))
  ],
  externals: {
    fs: 'fs', // To remove once https://github.com/benjamn/recast/pull/238 is released
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
            test: /\.(js|jsx)$/, //All .js and .jsx files
            loader: 'babel-loader?optional=runtime&stage=0', //babel loads jsx and es6-7
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
            test: /\.css$/,
            loader: "style-loader!css-loader"
          },
        ]
  },
  eslint: {
    configFile: '../.eslintrc'
  }
};

module.exports = config;
