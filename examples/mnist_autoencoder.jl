# based on http://int8.io/automatic-differentiation-machine-learning-julia/

using MNIST # if not installed try Pkg.add("MNIST")
using AutoDiffSource # if not installed try Pkg.add("AutoDiffSource")
using PyPlot # if not installed try Pkg.add("PyPlot")

@δ sigmoid(x) = 1 ./ (1 + exp.(-x))
@δ sum_sigmoid(x) = sum(sigmoid(x))
@assert checkdiff(sum_sigmoid, δsum_sigmoid, randn(10))

@δ function autoencoder(We1, We2 , Wd, b1, b2,  input)
    firstLayer = sigmoid(We1 * input .+ b1)
    encodedInput = sigmoid(We2 * firstLayer .+ b2)
    reconstructedInput = sigmoid(Wd * encodedInput)
end

@δ function autoencoderError(We1, We2 , Wd, b1, b2,  input)
    reconstructedInput = autoencoder(We1, We2 , Wd, b1, b2,  input)
    return sum((input .- reconstructedInput).^2)
end
@assert checkdiff(autoencoderError, δautoencoderError, randn(3,3), randn(3,3), rand(3,3), randn(3), randn(3), randn(3))

function initializeNetworkParams(inputSize, layer1Size, layer2Size)
    We1 =  0.1 * randn(layer1Size, inputSize)
    b1 = zeros(layer1Size, 1)
    We2 =  0.1 * randn(layer2Size, layer1Size)
    b2 = zeros(layer2Size, 1)
    Wd = 0.1 * randn(inputSize, layer2Size)
    return (We1, We2, b1, b2, Wd)
end

function show_digits(testing, We1, We2, b1, b2, Wd)
    clf()
    total_error = 0
    for l = 1:12
        input = testing[:, rand(1:size(testing, 2))]
        reconstructedInput = autoencoder(We1, We2 , Wd, b1, b2,  input)
        subplot(4, 6, l*2-1)
        title("input")
        pcolor(rotl90(reshape(input, 28, 28)'); cmap="Greys")
        subplot(4, 6, l*2)
        title("reconstructed")
        pcolor(rotl90(reshape(reconstructedInput, 28, 28)'); cmap="Greys")
        total_error += sum((input .- reconstructedInput).^2)
    end
    total_error / 6
end

function trainAutoencoder(epochs, training, testing, We1, We2, b1, b2, Wd, alpha)
    for k in 1:epochs
        total_error = 0.
        for i in 1:size(training, 2)
            input = training[:,i]
            val, ∇autoencoderError = δautoencoderError(We1, We2, Wd, b1, b2, input)
            total_error += val
            if mod(i, 1000) == 0
                test_error = show_digits(testing, We1, We2, b1, b2, Wd)
                @printf("epoch=%d iter=%d train_error=%.2f test_error=%.2f\n", k, i, total_error/1000, test_error)
                total_error = 0.
            end
            ∂We1, ∂We2, ∂Wd, ∂b1, ∂b2 = ∇autoencoderError()
            We1 -= alpha * ∂We1
            We2 -= alpha * ∂We2
            Wd  -= alpha * ∂Wd
            b1  -= alpha * ∂b1
            b2  -= alpha * ∂b2
        end
    end
    return (We1, We2, b1, b2, Wd)
end

# read input MNIST data
training = MNIST.traindata()[1] / 255
testing = MNIST.testdata()[1] / 255

# 784 -> 300 -> 100 -> 784 with weights normally distributed (with small variance)
We1, We2, b1, b2, Wd = initializeNetworkParams(784, 300, 100)

# 4 epochs with alpha = 0.02
@time We1, We2, b1, b2, Wd = trainAutoencoder(4, training, testing, We1, We2, b1, b2, Wd, 0.02)

for k = 1:10
    show_digits(testing, We1, We2, b1, b2, Wd)
end
