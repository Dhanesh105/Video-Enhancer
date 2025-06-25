function processVideo(videoFile, outputFile)
% processVideo Enhances a video with stabilization, denoising, super-resolution, and contrast enhancement.
%   processVideo(videoFile, outputFile) reads a video from videoFile,
%   applies a series of enhancements, and saves the result to outputFile.

disp('Starting video enhancement...');
fprintf('Input file: %s\n', videoFile);
fprintf('Output file: %s\n', outputFile);

try
    % --- Setup Paths for Intermediate Files ---
    [outputDir, outputName, ~] = fileparts(outputFile);
    denoisedOutputFile = fullfile(outputDir, [outputName '_denoised.mp4']);
    superResOutputFile = fullfile(outputDir, [outputName '_superres.mp4']);

    % Step 1: Read the Video
    vidObj = VideoReader(videoFile);
    numFrames = round(vidObj.Duration * vidObj.FrameRate);

    % Step 2: Create VideoWriter Objects
    outputVid = VideoWriter(outputFile, 'MPEG-4');
    open(outputVid);
    denoisedVid = VideoWriter(denoisedOutputFile, 'MPEG-4');
    open(denoisedVid);
    superResVid = VideoWriter(superResOutputFile, 'MPEG-4');
    open(superResVid);

    % Initialize optical flow object for stabilization
    opticFlow = opticalFlowLK('NoiseThreshold', 0.01);
    cumulativeMotionX = 0;
    cumulativeMotionY = 0;

    % Step 3: Process Each Frame
    for k = 1:numFrames
        % Read a frame
        frame = read(vidObj, k);
        % Convert to grayscale for optical flow
        grayFrame = rgb2gray(frame);

        % Stabilization
        if k > 1
            flow = estimateFlow(opticFlow, grayFrame);
            cumulativeMotionX = cumulativeMotionX + mean(flow.Vx(:));
            cumulativeMotionY = cumulativeMotionY + mean(flow.Vy(:));
            tform = affine2d([1 0 0; 0 1 0; -cumulativeMotionX -cumulativeMotionY 1]);
            outputRef = imref2d(size(frame));
            stabilizedFrame = imwarp(frame, tform, 'OutputView', outputRef);
        else
            stabilizedFrame = frame; % First frame, no stabilization needed
        end

        % Step 4: Apply Non-Local Means Denoising
        denoisedFrame = imnlmfilt(stabilizedFrame, 'DegreeOfSmoothing', 0.01);
        writeVideo(denoisedVid, uint8(denoisedFrame));

        % Step 5: Enhance Resolution (Super Resolution)
        superResFrame = imresize(denoisedFrame, 2, 'bilinear');
        writeVideo(superResVid, superResFrame);

        % Step 6: Enhance Contrast using Histogram Equalization on Value channel
        hsvFrame = rgb2hsv(uint8(superResFrame));
        hsvFrame(:,:,3) = histeq(hsvFrame(:,:,3));
        enhancedFrameRGB = hsv2rgb(hsvFrame);

        % Write the final processed frame to the output video
        writeVideo(outputVid, enhancedFrameRGB);

        fprintf('Processed frame %d of %d\n', k, numFrames);
    end

    % Step 7: Close VideoWriter objects
    close(outputVid);
    close(denoisedVid);
    close(superResVid);

    disp('Video processing complete!');
    exit(0); % Exit MATLAB with a success code

catch ME
    fprintf(2, 'Error processing video: %s\n', ME.message);
    fprintf(2, 'Error in %s on line %d\n', ME.stack(1).name, ME.stack(1).line);
    exit(1); % Exit MATLAB with a failure code
end

end
