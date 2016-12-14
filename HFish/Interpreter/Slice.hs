{-# language LambdaCase, OverloadedStrings #-}
module HFish.Interpreter.Slice (
  Slices
  ,makeSlices
  ,readSlices
  ,writeSlices
) where

import Fish.Lang
import HFish.Interpreter.Core
import HFish.Interpreter.Util

import qualified Data.List as L
import qualified Data.Text as T
import Data.Tuple
import Data.Monoid
import Data.Bool
import Data.Bifunctor
import Control.Monad
import Control.Monad.IO.Class
import qualified Control.Exception as E

{- Implements fish style array slicing -}

type Slices = [(Bool,(Int,Int))]

makeSlices :: Int -> [(Int,Int)] -> Fish Slices
makeSlices l xs = 
  L.sortOn (fst . snd)
  . map markSwap
  <$> forM xs normalise
  where
    normalise (i,j) = do
      a <- index i
      b <- index j
      return (a,b)
    markSwap (i,j) = bool (False,(i,j)) (True,(j,i)) (i>j)
    index i
      | 0 < i && i <= l = return (i - 1)
      | -l <= i && i < 0 = return (l + i)
      | otherwise = errork
        $ "Index \"" <> showText i <> "\" is out of bounds"

readSlices :: Slices -> [a] -> [a]
readSlices = work 0
  where
    work n slcs xs = case slcs of
      [] -> []
      (b,(i,j)):rest -> 
        let (_,xs') = splitAt (i-n) xs
            (ys,_) = splitAt (j-i+1) xs'
            done = work i rest xs'
         in mbRev b ys ++ done

{- writeSlices may fail if the ranges overlap -}
writeSlices :: Show a => Slices -> [a] -> [a] -> Fish [a]
writeSlices slcs xs ys =
  liftIO (E.try $ E.evaluate $ work 0 slcs xs ys)
  >>= \case
    Left e -> errork $ showText (e :: E.ErrorCall)
    Right zs -> return zs
  where
    work n slcs xs ys =
      case slcs of
        [] -> bool tooManyErr xs (isEmpty ys)
        (b,(i,j)):rest -> 
          case triSplit (i-n) (j-i+1) xs of
            Nothing -> invalidIndicesErr slcs
            Just (hs,_,xs') ->
              case splitAtMaybe (j-i+1) ys of
                Nothing -> tooFewErr
                Just (rs,ys') -> 
                  let done = work (j+1) rest xs' ys'
                   in (hs ++ mbRev b rs ++ done)
    
    tooFewErr = error "Too few values to write."
    tooManyErr = error "Too many values to write."
    invalidIndicesErr slcs = error
      $ "Invalid indices (out of bounds or overlapping): "
        ++ showSlices slcs
    

showSlices :: Slices -> String
showSlices slcs = 
  arrify . unwords
  $ map (sugar . unNormalise . unMarkSwap) slcs
  where
    unMarkSwap (b,(i,j)) = bool id swap b (i,j)
    unNormalise = bimap unIndex unIndex
    unIndex i = i+1
    arrify s = "[" ++ s ++ "]"
    sugar (i,j) = show i ++ ".." ++ show j
    

triSplit :: Int -> Int -> [a] -> Maybe ([a],[a],[a])
triSplit i j xs = do
  (hs,xs') <- splitAtMaybe i xs
  (xs'',ts) <- splitAtMaybe j xs'
  Just (hs,xs'',ts)
    
mbRev :: Bool -> [a] -> [a]
mbRev = bool id reverse

isEmpty :: [a] -> Bool
isEmpty = \case
  [] -> True
  _ -> False
