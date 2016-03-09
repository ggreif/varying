module Main where

import Test.Hspec hiding (after)
import Test.QuickCheck
import Control.Varying
import Data.Functor.Identity
import Control.Monad.IO.Class

main :: IO ()
main = hspec $ do
  describe "timeAsPercentageOf" $ do
      it "should run past 1.0" $ do
          let Identity scans = scanVar (timeAsPercentageOf 4)
                                       [1,1,1,1,1 :: Float]
          last scans `shouldSatisfy` (> 1)
      it "should progress by increments of the total" $ do
          let Identity scans = scanVar (timeAsPercentageOf 4)
                                       [1,1,1,1,1 :: Float]
          scans `shouldBe` [0.25,0.5,0.75,1.0,1.25 :: Float]

  describe "tween" $
      it "should step by the dt passed in" $ do
          let Identity scans = scanSpline (tween linear 0 4 (4 :: Float)) 0
                                          [0,1,1,1,1,1]
          scans `shouldBe` [0,1,2,3,4,4]

  describe "untilEvent" $ do
      let Identity scans = scanSpline (3 `untilEvent` (1 ~> after 10)) 0
                                      (replicate 10 ())
      it "should produce output from the value stream until event procs" $
          head scans `shouldBe` 3
      it "should produce output from the value stream until event procs" $
          last scans `shouldBe` 3

  describe "step" $ do
      let s = do step "hey"
                 step ", "
                 step "there"
                 step "."
          Identity scans = scanSpline s "" $ replicate 6 ()
      it "should produce output exactly one time per call" $
        concat scans `shouldBe` "hey, there..."

  describe "race" $ do
      let s1 = do step "s10"
                  step "s11"
                  step "s12"
                  return 1
          s2 = do step "s20"
                  step "s21"
                  return True
          r = do step "start"
                 eIntBool <- race (\a b -> concat [a,":",b]) s1 s2
                 case eIntBool of
                   Left i -> step $ "left won with " ++ show i
                   Right b -> step $ "right won with " ++ show b
          Identity scans = scanSpline r "" $ replicate 4 ()
      it "scans" $ unwords scans `shouldBe` "start s10:s20 s11:s21 right won with True"

  describe "capture" $ do
      let r :: Spline () String ()
          r = do x <- capture $ do step "a"
                                   step "b"
                                   return 2
                 case x of
                   (Just "b", 2) -> step "True"
                   _ -> step "False"
          scans = scanSpline r "" $ replicate 3 ()
      it "should end with the last value captured" $
          unwords (concat scans) `shouldBe` "a b True"


  describe "mapOutput" $ do
      let s :: Spline a Char ()
          s = do step 'a'
                 step 'b'
                 step 'c'
                 let f = pure toEnum
                 mapOutput f $ do step 100
                                  step 101
                                  step 102
                 step 'g'
          Identity scans = scanSpline s 'x' $ replicate 7 ()
      it "should map the output" $
          scans `shouldBe` "abcdefg"

  describe "adjustInput" $ do
      let s = var id `untilEvent_` never
          v :: Var a (Char -> Int)
          v = pure fromEnum
          s' = adjustInput v s
          Identity scans = scanSpline s' 0 "abcd"
      it "should" $ scans `shouldBe` [97,98,99,100]
--------------------------------------------------------------------------------
-- Adherance to typeclass laws
--------------------------------------------------------------------------------
  let inc = 1 ~> accumulate (+) 0
      sinc :: Spline a Int Int
      sinc = inc `untilEvent_` (1 ~> after 3)
      go a = scanSpline a 0 [0..9]
      equal a b = go a `shouldBe` go b

  describe "spline's functor instance" $ do
    let sincf = fmap id sinc
    it "fmap id = id" $ equal sinc sincf
    let g :: Int -> Int
        g x = x + 1
        f x = x - 1
        sdot = fmap (g . f) sinc
        sfdot = fmap g $ fmap f sinc
    it "fmap (g . f) = fmap g . fmap f" $ equal sdot sfdot

  describe "spline's applicative instance" $ do
    let ident = pure id <*> sinc
    it "(identity) pure id <*> v = v" $ equal ident sinc
    let pfpx :: Spline a Int Int
        pfpx = pure (+1) <*> pure 1
        pfx = pure (1+1)
    it "(homomorphism) pure f <*> pure x = pure (f x)" $ equal pfpx pfx
    let u :: Spline a Int (Int -> Int)
        u = pure 66 `_untilEvent` (use (+1) $ 1 ~> after 3)
        upy = u <*> pure 1
        pyu = pure ($ 1) <*> u
    it "(interchange) u <*> pure y = pure ($ y) <*> u" $ equal upy pyu
    let v :: Spline a Int (Int -> Int)
        v = pure 66 `_untilEvent` (use (1-) $ 1 ~> after 4)
        w = pure 72 `_untilEvent` (use 3 $ 1 ~> after 1)
        pduvw = pure (.) <*> u <*> v <*> w
        uvw = u <*> (v <*> w)
    it "(compisition) pure (.) <*> u <*> v <*> w = u <*> (v <*> w)" $
      equal pduvw uvw

  describe "spline's monad instance" $ do
    let m = sinc
        mr = m >>= return
        p :: Spline a Int Int
        p = pure 1

    it "(right unit w/ const) m >>= return = m" $ equal (p >>= return) p
    it "(right unit) m >>= return = m" $ equal m mr