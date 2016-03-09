module Main where

import Control.Varying
import Control.Applicative
import Text.Printf
import Data.Functor.Identity
import Data.Time.Clock

-- | A simple 2d point type.
data Point = Point { px :: Float
                   , py :: Float
                   } deriving (Show, Eq)

newtype Delta = Delta { unDelta :: Float }

-- An exponential tween back and forth from 0 to 100 over 2 seconds that
-- loops forever. This spline takes float values of delta time as input,
-- outputs the current x value at every step and would result in () if it
-- terminated.
tweenx :: (Applicative m, Monad m) => SplineT Float Float m Float
tweenx = do
    -- Tween from 0 to 100 over 1 second
    x <- tween easeOutExpo 0 100 1
    -- Chain another tween back to the starting position
    _ <- tween easeOutExpo x 0 1
    -- Loop forever
    tweenx

-- A quadratic tween back and forth from 0 to 100 over 2 seconds that never
-- ends.
tweeny :: (Applicative m, Monad m) => SplineT Float Float m Float
tweeny = do
    y <- tween easeOutQuad 0 100 1
    _ <- tween easeOutQuad y 0 1
    tweeny

-- Our time signal counts input delta time samples.
time :: Monad m => VarT m Delta Float
time = var unDelta ~> accumulate (+) 0

-- | Our Point value that varies over time continuously in x and y.
backAndForth :: Monad m => VarT m Delta Point
backAndForth =
    -- Turn our splines into continuous output streams. We must provide
    -- a starting value since splines are not guaranteed to be defined at
    -- their edges.
    let x = outputStream tweenx 0
        y = outputStream tweeny 0
    in
    -- Construct a varying Point that takes time as an input.
    (Point <$> x <*> y)
        -- Stream in a time signal using the 'plug left' combinator.
        -- We could similarly use the 'plug right' (>>>) function
        -- and put the time signal before the construction above. This is needed
        -- because the tween streams take time as an input.
        <~ time

main :: IO ()
main = do
    putStrLn "An example of value streams using the varying library."
    putStrLn "Enter a newline to continue, quit with ctrl+c"
    _ <- getLine
    utc0 <- getCurrentTime

    loop backAndForth utc0
        where loop v utc1 = do utc2 <- getCurrentTime
                               let dt = realToFrac $ diffUTCTime utc2 utc1
                               (point, vNext) <- runVarT v $ Delta dt
                               printf "\nPoint %03.1f %03.1f" (px point) (py point)
                               loop vNext utc2

