{-# language LambdaCase, GADTs, OverloadedStrings, TupleSections #-}
module HFish.Interpreter.Builtins.Seq (
  seqF
) where

import Fish.Lang
import HFish.Interpreter.Core
import HFish.Interpreter.IO
import HFish.Interpreter.Concurrent
import HFish.Interpreter.Process.Process
import HFish.Interpreter.Status
import HFish.Interpreter.Util
import qualified HFish.Interpreter.Stringy as Str

import Control.Lens
import Control.Monad
import Control.Monad.IO.Class
import Control.Concurrent
import qualified Data.ByteString.Builder.Prim as BP
import qualified Data.ByteString.Builder as B
import Text.Read
import Data.Functor
import Data.Monoid
import System.Exit
import System.IO

seqF :: Builtin
seqF fork = \case
  [] -> errork "seq: too few arguments given"
  [l] -> seqFWorker fork ((1,1,) <$> mread l)
  [f,l] -> seqFWorker fork ((,1,) <$> mread f <*> mread l)
  [f,i,l] -> seqFWorker fork ((,,) <$> mread f <*> mread i <*> mread l)
  _ -> errork "seq: too many arguments given"
  where
    mread = Str.readStrMaybe

seqFWorker :: Bool -> Maybe (Int,Int,Int) -> Fish ()
seqFWorker fork = \case
    Nothing -> errork "seq: invalid argument(s) given"
    Just (a,b,c) -> do
      if fork
        then forkFish (writeList a b c) >> ok
        else writeList a b c >> ok

writeList :: Int -> Int -> Int -> Fish ()
writeList a b c = echo
  . B.toLazyByteString
  $ createList a b c

createList :: Int -> Int -> Int -> B.Builder
createList a b c = BP.primUnfoldrBounded intLn next a
  where
    next i = do
      guard (i <= c)
      Just ((i,'\n'),i+b)
    intLn = BP.intDec BP.>*< BP.charUtf8



