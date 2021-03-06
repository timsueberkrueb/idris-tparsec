module TParsec.Combinators.Chars

import Relation.Indexed
import Relation.Subset
import Induction.Nat
import Data.Digit
import Data.Inspect
import Data.NEList
import Data.Vect
import TParsec.Types
import TParsec.Combinators
import TParsec.Combinators.Numbers

%default total
%access public export

char : ( Alternative mn, Monad mn
       , Subset Char (Tok p)
       , Eq (Tok p), Inspect (Toks p) (Tok p)
       ) => Char -> All (Parser mn p (Tok p))
char = exact . into

anyCharBut : ( Alternative mn, Monad mn
             , Subset Char (Tok p)
             , Eq (Tok p), Inspect (Toks p) (Tok p)
             ) => Char -> All (Parser mn p (Tok p))
anyCharBut = anyTokenBut . into

noneOfChars : ( Alternative mn, Monad mn
              , Subset Char (Tok p)
              , Eq (Tok p), Inspect (Toks p) (Tok p)
              ) => List Char -> All (Parser mn p (Tok p))
noneOfChars = noneOf . map into

string : ( Alternative mn, Monad mn
         , Subset Char (Tok p)
         , Eq (Tok p), Inspect (Toks p) (Tok p)
         ) => (t : String) -> {auto pr : NonEmpty (unpack t)} ->
         All (Parser mn p String)
string t {pr} with (unpack t)
  | []        = absurd pr
  | (x :: xs) = cmap t (ands (map (\c => char c) $ MkNEList x xs))

space : ( Alternative mn, Monad mn
        , Subset Char (Tok p)
        , Eq (Tok p), Inspect (Toks p) (Tok p)
        ) => All (Parser mn p (Tok p))
space = anyOf (map into $ unpack " \t\n")

spaces : ( Alternative mn, Monad mn
         , Subset Char (Tok p)
         , Eq (Tok p), Inspect (Toks p) (Tok p)
         ) => All (Parser mn p (NEList (Tok p)))
spaces = nelist space

parens : ( Alternative mn, Monad mn
         , Subset Char (Tok p)
         , Eq (Tok p), Inspect (Toks p) (Tok p)
         ) => All (Box (Parser mn p a) :-> Parser mn p a)
parens = between (char '(') (char ')')

parensopt : ( Alternative mn, Monad mn
            , Subset Char (Tok p)
            , Eq (Tok p), Inspect (Toks p) (Tok p)
            ) => All (Parser mn p a :-> Parser mn p a)
parensopt = betweenopt (char '(') (char ')')

withSpaces : ( Alternative mn, Monad mn
             , Subset Char (Tok p)
             , Eq (Tok p), Inspect (Toks p) (Tok p)
             ) => All (Parser mn p a :-> Parser mn p a)
withSpaces p = roptand spaces (landopt p spaces)

lowerAlpha : ( Alternative mn, Monad mn
             , Subset Char (Tok p)
             , Eq (Tok p), Inspect (Toks p) (Tok p)
             ) => All (Parser mn p (Tok p))
lowerAlpha = anyOf (map into $ unpack "abcdefghijklmnopqrstuvwxyz")

upperAlpha : ( Alternative mn, Monad mn
             , Subset Char (Tok p)
             , Eq (Tok p), Inspect (Toks p) (Tok p)
             ) => All (Parser mn p (Tok p))
upperAlpha = anyOf (map into $ unpack "ABCDEFGHIJKLMNOPQRSTUVWXYZ")

alpha : ( Alternative mn, Monad mn
        , Subset Char (Tok p)
        , Eq (Tok p), Inspect (Toks p) (Tok p)
        ) => All (Parser mn p (Tok p))
alpha = lowerAlpha `alt` upperAlpha

-- TODO define Bijection?
alphas
  : ( Alternative mn, Monad mn
    , Subset Char (Tok p), Subset (Tok p) Char
    , Eq (Tok p), Inspect (Toks p) (Tok p)
    ) => All (Parser mn p String)
alphas = map (pack . map into . NEList.toList) (nelist alpha)

num : ( Alternative mn, Monad mn
      , Subset Char (Tok p)
      , Eq (Tok p), Inspect (Toks p) (Tok p)
      ) => All (Parser mn p Nat)
num = map toNat decimalDigit

alphanum
   : ( Alternative mn, Monad mn
     , Subset Char (Tok p)
     , Eq (Tok p), Inspect (Toks p) (Tok p)
     ) => All (Parser mn p (Either (Tok p) Nat))
alphanum = sum alpha num

||| A string literal is an opening and a closing double quote with
||| a chain of non-empty lists of characters that are neither a
||| double quote nor an escaping character.
||| This chain is separated by non-empty lists of blocks made of
||| an escaping character and its escapee.
||| Additionally, there may be another such block of escapees on
||| each side of the chain.
stringLiteral
  : ( Monad mn, Alternative mn
    , Inspect (Toks p) (Tok p), Eq (Tok p)
    , Subset Char (Tok p), Subset (Tok p) Char
    ) => All (Parser mn p String)
stringLiteral {mn} {p}
  = map convert
  $ and (randopt (char '"') escaped)
  $ box $ flip loptand (char '"')
  $ nelist (andopt unescaped (box escaped))

  where

    toks : Type
    toks = NEList (Tok p)

    fromToks : toks -> List Char
    fromToks = NEList.toList . map into

    fromMToks : Maybe toks -> List Char
    fromMToks = maybe [] fromToks

    unescaped : All (Parser mn p toks)
    unescaped = nelist (noneOfChars ['\\','"'])

    escaped : All (Parser mn p toks)
    escaped =
      let unicode : All (Parser mn p toks)
                  = map (MkNEList (into '\\') . ((into 'u') ::)
                        . toList . Functor.map (into . toChar))
                  $ replicate 4 hexadecimalDigit
      in map NEList.concat
       $ nelist
       $ map (\ (a, mb) => fromMaybe (singleton a) mb)
       $ rand (char '\\')
       $ box $ andoptbind anyTok $ \ c =>
         if c /= into 'u' then fail else unicode

    convert : (Maybe toks, Maybe (NEList (toks, Maybe toks))) -> String
    convert (mt, mts)
      = pack
      $ List.(++) (fromMToks mt)
      $ maybe [] (concatMap (\ (ts, mts) => fromToks ts ++ fromMToks mts))
      $ mts
