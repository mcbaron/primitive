# primitive

Reproducing images with geometric primitives.

This is an effort to reproduce the idea of primitive.lol[http://primitive.lol] in Julia.

## How it works
A target image is provided as input. The algorithm tries to find the single most optimal shape that can be drawn to minimize the error between the target image and the drawn image. It repeats this process, adding one shape at a time. Around 50 to 200 shapes are needed to reach a result that is recognizable yet artistic and abstract.

##How it Works, Part II

Say we have a Target Image. This is what we're working towards recreating. We start with a blank canvas, but we fill it with a single solid color. Currently, this is the average color of the Target Image. We call this new blank canvas the Current Image. Now, we start evaluating shapes. To evaluate a shape, we draw it on top of the Current Image, producing a New Image. This New Image is compared to the Target Image to compute a score. We use the root-mean-square error for the score.

Current Image + Shape => New Image
RMSE(New Image, Target Image) => Score

The shapes are generated randomly. We can generate a random shape and score it. Then we can mutate the shape (by tweaking a triangle vertex, tweaking an ellipse radius or center, etc.) and score it again. If the mutation improved the score, we keep it. Otherwise we rollback to the previous state. Repeating this process is known as hill climbing. Hill climbing is prone to getting stuck in local minima, so we actually do this many different times with several different starting shapes. We can also generate N random shapes and pick the best one before we start hill climbing. Simulated annealing is another good option, but in my tests I found the hill climbing technique just as good and faster, at least for this particular problem.

Once we have found a good-scoring shape, we add it to the Current Image, where it will remain unchanged. Then we start the process again to find the next shape to draw. This process is repeated as many times as desired.

##Other Optimization
I'd like to implement simulated annealing to see the difference in the convergence, but I'm publishing the project now for sake of moving on to other things. 
