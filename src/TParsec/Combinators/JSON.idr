module TParsec.Combinators.JSON

import Relation.Indexed
import Relation.Subset
import Data.Inspect
import Data.NEList as NEList
import Induction.Nat as Box
import TParsec.Types
import TParsec.Combinators
import TParsec.Combinators.Chars
import TParsec.Combinators.Numbers
import Language.JSON.Data

%default total
%access public export

--- We follow RFC 8259: https://tools.ietf.org/html/rfc8259

-- In this parser we assume that when we call a subparser all of the whitespace
-- before the potential token has been consumed already. That means that we should
-- systematically consume spaces after the tokens we have happily recognised.

-- Structural characters

beginArray
  : ( Monad mn, Alternative mn
    , Inspect (Toks p) (Tok p), Eq (Tok p)
    , Subset Char (Tok p)
    ) => All (Parser mn p ())
beginArray = cmap () $ andopt (char '[') spaces

beginObject
  : ( Monad mn, Alternative mn
    , Inspect (Toks p) (Tok p), Eq (Tok p)
    , Subset Char (Tok p)
    ) => All (Parser mn p ())
beginObject = cmap () $ andopt (char '{') spaces

endArray
  : ( Monad mn, Alternative mn
    , Inspect (Toks p) (Tok p), Eq (Tok p)
    , Subset Char (Tok p)
    ) => All (Parser mn p ())
endArray = cmap () $ andopt (char ']') spaces

endObject
  : ( Monad mn, Alternative mn
    , Inspect (Toks p) (Tok p), Eq (Tok p)
    , Subset Char (Tok p)
    ) => All (Parser mn p ())
endObject = cmap () $ andopt (char '}') spaces

nameSeparator
  : ( Monad mn, Alternative mn
    , Inspect (Toks p) (Tok p), Eq (Tok p)
    , Subset Char (Tok p)
    ) => All (Parser mn p ())
nameSeparator = cmap () $ andopt (char ':') spaces

valueSeparator
  : ( Monad mn, Alternative mn
    , Inspect (Toks p) (Tok p), Eq (Tok p)
    , Subset Char (Tok p)
    ) => All (Parser mn p ())
valueSeparator = cmap () $ andopt (char ',') spaces

||| Subparser for members, provided a subparser for smaller JSON objects
||| According to the RFC:
||| member = string name-separator value

member
  : ( Monad mn, Alternative mn
    , Inspect (Toks p) (Tok p), Eq (Tok p)
    , Subset Char (Tok p), Subset (Tok p) Char
    ) => All (Box (Parser mn p JSON) :-> Parser mn p (String, JSON))
member rec
  = and (landopt stringLiteral spaces)
  $ rand nameSeparator
  $ rec

||| Subparser for JSON objects, provided a subparser for smaller JSON objects
||| According to the RFC:
||| object = begin-object [ member *( value-separator member ) ] end-object

object
  : ( Monad mn, Alternative mn
    , Inspect (Toks p) (Tok p), Eq (Tok p)
    , Subset Char (Tok p), Subset (Tok p) Char
    ) => All (Box (Parser mn p JSON) :-> Parser mn p (List (String, JSON)))
object rec
  = map (maybe [] (\ (a, as) => NEList.toList (consopt a as)))
  $ flip land endObject
  $ randopt beginObject
  $ box $ andopt (member rec)
  $ nelist (rand valueSeparator (member rec))

||| Subparser for JSON arrays, provided a subparser for smaller JSON objects
||| According to the RFC:
||| array = begin-array [ value *( value-separator value ) ] end-array

array
  : ( Monad mn, Alternative mn
    , Inspect (Toks p) (Tok p), Eq (Tok p)
    , Subset Char (Tok p)
    ) => All (Box (Parser mn p JSON) :-> Parser mn p (List JSON))
array rec
  = map (maybe [] (\ (a, as) => NEList.toList (consopt a as)))
  $ flip land endArray
  $ randopt beginArray
  $ lift2l (\ p, q => andopt p (box q)) rec
  $ nelist (rand valueSeparator rec)

||| Parsing JSON values
value
  : ( Monad mn, Alternative mn
    , Inspect (Toks p) (Tok p), Eq (Tok p)
    , Subset Char (Tok p), Subset (Tok p) Char
    ) => All (Parser mn p JSON)
value {mn} {p} = roptand spaces $ fix (Parser mn p JSON) $ \ rec => alts
  [ cmap JNull            (landopt (string "null") spaces)
  , cmap (JBoolean True)  (landopt (string "true") spaces)
  , cmap (JBoolean False) (landopt (string "false") spaces)
  , map  JNumber          (landopt decimalDouble spaces)
  , map  JString          (landopt stringLiteral spaces)
  , map  JArray           (array rec)
  , map  JObject          (object rec)
  ]
