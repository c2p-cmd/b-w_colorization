# B&W Colorizer using CoreML

### This is a Colorizer which using a Deep-CNN and runs using CoreML
Essentially by converting [richzhang's pytorch colorizer](http://richzhang.github.io/colorization/) to CoreML. 
<br>
One can embed this in a any iOS/macOS/visionOS app and colorize old b&w images

#### You can look at the converter jupyter notebook
- [here](./convert.ipynb)

#### Or download the models directly
- [eccv16](./ECCV16Colorize.mlpackage.zip)
- [siggraph17](./SIGGraph17Colorizer.mlpackage.zip)

#### Demo app
- [at BWColorizer](./BWColorizer/BWColorizer/)
- Video
<video src="https://github.com/c2p-cmd/b-w_colorization/raw/main/Simulator%20Screen%20Recording%20-%20iPhone%2015%20Pro%20-%202024-07-20%20at%2018.39.56.mp4">

### Credits
- [OnSwiftWings](https://www.onswiftwings.com/posts/image-colorization-coreml/#)
- [richzhang](http://richzhang.github.io/colorization/)