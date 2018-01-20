{-# LANGUAGE OverloadedStrings #-}

module Main(main) where

import           Data.Binary
import           Data.Char
import           Data.Maybe
import           Data.Monoid
import qualified Data.String               as D.S
import qualified Data.Text                 as T
import qualified Data.Text.Encoding        as T
import qualified Data.Text.Short           as IUT
import           Test.QuickCheck.Instances ()
import           Test.Tasty
import           Test.Tasty.HUnit
import           Test.Tasty.QuickCheck     as QC

fromByteStringRef = either (const Nothing) (Just . IUT.fromText) . T.decodeUtf8'

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests = testGroup "Tests" [unitTests,qcProps]

-- ShortText w/ in-bounds index
data STI = STI IUT.ShortText Int
         deriving (Eq,Show)

instance Arbitrary STI where
  arbitrary = do
    t <- arbitrary
    i <- choose (0, T.length t - 1)
    return $! STI (IUT.fromText t) i

qcProps :: TestTree
qcProps = testGroup "Properties"
  [ QC.testProperty "length/fromText"   $ \t -> IUT.length (IUT.fromText t) == T.length t
  , QC.testProperty "length/fromString" $ \s -> IUT.length (IUT.fromString s) == length s
  , QC.testProperty "compare" $ \t1 t2 -> IUT.fromText t1 `compare` IUT.fromText t2  == t1 `compare` t2
  , QC.testProperty "(==)" $ \t1 t2 -> (IUT.fromText t1 == IUT.fromText t2)  == (t1 == t2)
  , QC.testProperty "(!?)" $ \t ->
      let t' = IUT.fromText t
      in and [ mapMaybe (t' IUT.!?) [0 .. T.length t -1 ] == T.unpack t
             , mapMaybe (t' IUT.!?) [-5 .. -1] == []
             , mapMaybe (t' IUT.!?) [T.length t .. T.length t + 5] == []
             ]
  , QC.testProperty "indexEndMaybe" $ \t ->
      let t' = IUT.fromText t
      in and [ mapMaybe (IUT.indexEndMaybe t') [0 .. T.length t -1 ] == T.unpack (T.reverse t)
             , mapMaybe (IUT.indexEndMaybe t') [-5 .. -1] == []
             , mapMaybe (IUT.indexEndMaybe t') [T.length t .. T.length t + 5] == []
             ]
  , QC.testProperty "toText.fromText"   $ \t -> (IUT.toText . IUT.fromText) t == t
  , QC.testProperty "fromByteString"    $ \b -> IUT.fromByteString b == fromByteStringRef b
  , QC.testProperty "fromByteString.toByteString" $ \t -> let ts = IUT.fromText t in (IUT.fromByteString . IUT.toByteString) ts == Just ts
  , QC.testProperty "toString.fromString" $ \s -> (IUT.toString . IUT.fromString) s == s
  , QC.testProperty "isAscii"  $ \s -> IUT.isAscii (IUT.fromString s) == all isAscii s
  , QC.testProperty "isAscii2" $ \t -> IUT.isAscii (IUT.fromText t)   == T.all isAscii t
  , QC.testProperty "splitAt" $ \t ->
      let t' = IUT.fromText t
          mapBoth f (x,y) = (f x, f y)
      in and [ mapBoth IUT.toText (IUT.splitAt i t') == T.splitAt i t | i <- [-5 .. 5+T.length t ] ]

  , QC.testProperty "splitAtEnd" $ \t ->
      let t' = IUT.fromText t
          n' = IUT.length t'
      in and [ (IUT.splitAt (n'-i) t') == IUT.splitAtEnd i t' | i <- [-5 .. 5+n' ] ]

  , QC.testProperty "find" $ \t -> IUT.find Data.Char.isAscii (IUT.fromText t) == T.find Data.Char.isAscii t
  , QC.testProperty "findIndex" $ \t -> IUT.findIndex Data.Char.isAscii (IUT.fromText t) == T.findIndex Data.Char.isAscii t

  , QC.testProperty "isSuffixOf" $ \t1 t2 -> IUT.fromText t1 `IUT.isSuffixOf` IUT.fromText t2  == t1 `T.isSuffixOf` t2
  , QC.testProperty "isPrefixOf" $ \t1 t2 -> IUT.fromText t1 `IUT.isPrefixOf` IUT.fromText t2  == t1 `T.isPrefixOf` t2

  , QC.testProperty "stripPrefix" $ \t1 t2 -> IUT.stripPrefix (IUT.fromText t1) (IUT.fromText t2) ==
                                                fmap IUT.fromText (T.stripPrefix t1 t2)

  , QC.testProperty "stripSuffix" $ \t1 t2 -> IUT.stripSuffix (IUT.fromText t1) (IUT.fromText t2) ==
                                                fmap IUT.fromText (T.stripSuffix t1 t2)

  , QC.testProperty "stripPrefix 2" $ \(STI t i) ->
      let (pfx,sfx) = IUT.splitAt i t
      in IUT.stripPrefix pfx t == Just sfx

  , QC.testProperty "stripSuffix 2" $ \(STI t i) ->
      let (pfx,sfx) = IUT.splitAt i t
      in IUT.stripSuffix sfx t == Just pfx

  , QC.testProperty "cons" $ \c t -> IUT.singleton c <> IUT.fromText t == IUT.cons c (IUT.fromText t)
  , QC.testProperty "snoc" $ \c t -> IUT.fromText t <> IUT.singleton c == IUT.snoc (IUT.fromText t) c

  , QC.testProperty "uncons" $ \c t -> IUT.uncons (IUT.singleton c <> IUT.fromText t) == Just (c, IUT.fromText t)

  , QC.testProperty "unsnoc" $ \c t -> IUT.unsnoc (IUT.fromText t <> IUT.singleton c) == Just (IUT.fromText t, c)

  , QC.testProperty "break" $ \t -> let (l,r)   = IUT.break Data.Char.isAscii (IUT.fromText t)
                                    in  T.break Data.Char.isAscii t == (IUT.toText l,IUT.toText r)

  , QC.testProperty "span"  $ \t -> let (l,r)   = IUT.span Data.Char.isAscii (IUT.fromText t)
                                    in  T.span Data.Char.isAscii t == (IUT.toText l,IUT.toText r)

  , QC.testProperty "breakEnd" $ \t -> let (l,r)   = IUT.breakEnd Data.Char.isAscii (IUT.fromText t)
                                       in  t_breakEnd Data.Char.isAscii t == (IUT.toText l,IUT.toText r)

  , QC.testProperty "spanEnd"  $ \t -> let (l,r)   = IUT.spanEnd Data.Char.isAscii (IUT.fromText t)
                                       in  t_spanEnd Data.Char.isAscii t == (IUT.toText l,IUT.toText r)

  , QC.testProperty "splitAt/isPrefixOf" $ \t ->
      let t' = IUT.fromText t
      in and [ IUT.isPrefixOf (fst (IUT.splitAt i t')) t' | i <- [-5 .. 5+T.length t ] ]
  , QC.testProperty "splitAt/isSuffixOf" $ \t ->
      let t' = IUT.fromText t
      in and [ IUT.isSuffixOf (snd (IUT.splitAt i t')) t' | i <- [-5 .. 5+T.length t ] ]
  ]

t_breakEnd p t = t_spanEnd (not . p) t
t_spanEnd  p t = (T.dropWhileEnd p t, T.takeWhileEnd p t)

unitTests = testGroup "Unit-tests"
  [ testCase "fromText mempty" $ IUT.fromText mempty @?= mempty
  , testCase "fromShortByteString [0xc0,0x80]" $ IUT.fromShortByteString "\xc0\x80" @?= Nothing
  , testCase "fromByteString [0xc0,0x80]" $ IUT.fromByteString "\xc0\x80" @?= Nothing
  , testCase "fromByteString [0xf0,0x90,0x80,0x80]" $ IUT.fromByteString "\xf0\x90\x80\x80" @?= Just "\x10000"
  , testCase "fromByteString [0xf4,0x90,0x80,0x80]" $ IUT.fromByteString "\244\144\128\128" @?= Nothing
  , testCase "IsString U+D800" $ "\xFFFD" @?= (IUT.fromString "\xD800")
--  , testCase "IsString U+D800" $ (IUT.fromString "\xD800") @?= IUT.fromText ("\xD800" :: T.Text)

  , testCase "Binary.encode" $ encode ("Hello \8364 & \171581!\NUL" :: IUT.ShortText) @?= "\NUL\NUL\NUL\NUL\NUL\NUL\NUL\DC2Hello \226\130\172 & \240\169\184\189!\NUL"
  , testCase "Binary.decode" $ decode ("\NUL\NUL\NUL\NUL\NUL\NUL\NUL\DC2Hello \226\130\172 & \240\169\184\189!\NUL") @?= ("Hello \8364 & \171581!\NUL" :: IUT.ShortText)
  , testCase "singleton" $ [ c | c <- [minBound..maxBound], IUT.singleton c /= IUT.fromText (T.singleton c) ] @?= []

  , testCase "splitAtEnd" $ IUT.splitAtEnd 1 "€€" @?= ("€","€")

  , testCase "literal0" $ IUT.unpack testLit0 @?= []
  , testCase "literal1" $ IUT.unpack testLit1 @?= ['€','\0','€','\0']
  , testCase "literal2" $ IUT.unpack testLit2 @?= ['\xFFFD','\xD7FF','\xFFFD','\xE000']
  ]

-- isScalar :: Char -> Bool
-- isScalar c = c < '\xD800' || c >= '\xE000'


{-# NOINLINE testLit0 #-}
testLit0 :: IUT.ShortText
testLit0 = ""

{-# NOINLINE testLit1 #-}
testLit1 :: IUT.ShortText
testLit1 = "€\NUL€\NUL"

{-# NOINLINE testLit2 #-}
testLit2 :: IUT.ShortText
testLit2 = "\xD800\xD7FF\xDFFF\xE000"
