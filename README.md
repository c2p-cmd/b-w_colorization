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
- [At BWColorizer SwiftUI App](./BWColorizer/BWColorizer/)
- [Video](https://github.com/c2p-cmd/b-w_colorization/raw/main/Simulator%20Screen%20Recording%20-%20iPhone%2015%20Pro%20-%202024-07-20%20at%2018.39.56.mp4)
<video src="https://github.com/c2p-cmd/b-w_colorization/raw/main/Simulator%20Screen%20Recording%20-%20iPhone%2015%20Pro%20-%202024-07-20%20at%2018.39.56.mp4">

#### How it works?
- Essentialy this is a pytorch model [ECCV16Colorizer](https://github.com/richzhang/colorization/blob/master/colorizers/eccv16.py) that has been converted to CoreML
1. Convert the `UIImage` to a `MLShapedArray<Float>` [1, 3, 512, 512] shape
2. Then convert to same to Lab color space array [1, 1, 512, 512] shape
3. Use this array's 'L' part to predict the 'ab' part of the image's Lab color Space Image
4. We get an `MLShapedArray<Float>` [1, 2, 512, 512] then using the original 'L' array we can combine and get the Lab of the predicted Image
5. Convert back to RGB space and convert the array to `UIImage`.

### Credits
- [OnSwiftWings](https://www.onswiftwings.com/posts/image-colorization-coreml/#)
- [richzhang](http://richzhang.github.io/colorization/)
