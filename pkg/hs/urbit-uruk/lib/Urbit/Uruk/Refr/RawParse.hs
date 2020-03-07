{-# OPTIONS_GHC -Wall -Werror #-}

module Urbit.Uruk.Refr.RawParse where

import ClassyPrelude hiding (exp, init, last, many, some, try)

import Control.Lens
import Control.Monad.State.Lazy
import Text.Megaparsec
import Text.Megaparsec.Char
import Data.Tree

import Control.Arrow ((>>>))
import Data.Void     (Void)

import qualified Urbit.Uruk.Refr.Raw as R


-- Types -----------------------------------------------------------------------

infixl 5 :@;

data AST = N Text | AST :@ AST
 deriving (Eq, Ord)

tree ∷ AST → Tree Text
tree = go [] where go a = \case { N n → Node n a; x :@ y → go (tree y:a) x }

unTree ∷ Tree Text → AST
unTree (Node n xs) = foldl' (:@) (N n) (unTree <$> xs)

showTree ∷ Tree Text -> String
showTree (Node n []) = unpack n
showTree (Node n xs) = "(" <> intercalate " " (unpack n : fmap showTree xs) <> ")"

instance Show AST where
  show = showTree . tree


-- Parser Monad ----------------------------------------------------------------

data Mode = Wide | Tall

type Parser = StateT Mode (Parsec Void Text)

inWideMode :: Parser a -> Parser a
inWideMode = withLocalState Wide
 where
  withLocalState :: Monad m => s -> StateT s m a -> StateT s m a
  withLocalState val x = do
    old <- get
    put val
    x <* put old

-- Simple Lexers ---------------------------------------------------------------

ace, pal, par :: Parser ()
ace = void (char ' ')
pal = void (char '(')
par = void (char ')')

bulkSpace :: Parser ()
bulkSpace = void (many spaceChar)

gap :: Parser ()
gap = (void (string "  ") <|> void (char '\n')) >> bulkSpace

whitespace :: Parser ()
whitespace = gap <|> ace

sym :: Parser Text
sym = fmap pack $ some $ oneOf ("$" <> ['a' .. 'z'] <> ['A' .. 'Z'])


-- Grammar ---------------------------------------------------------------------

exp :: Parser AST
exp = try rune <|> irregular

apN :: [AST] -> AST
apN []       = error "empty function application"
apN [x     ] = x
apN (x : xs) = go x xs
 where
  go acc []       = acc
  go acc (y : ys) = go (acc :@ y) ys

ap3 :: AST -> AST -> AST -> AST
ap3 x y z = apN [x, y, z]

ap4 :: AST -> AST -> AST -> AST -> AST
ap4 x y z p = apN [x, y, z, p]

irregular :: Parser AST
irregular = inWideMode $ choice
  [ apN <$> grouped "(" " " ")" exp
  , N <$> sym
  ]

sig :: Parser [Text]
sig = grouped "(" " " ")" sym <|> (: []) <$> sym

rune :: Parser AST
rune = choice
  [ string "%-" *> rune2 (:@) exp exp
  , string "%+" *> rune3 ap3 exp exp exp
  , string "%^" *> rune4 ap4 exp exp exp exp
  ]


-- Groups and binders ----------------------------------------------------------

grouped :: Text -> Text -> Text -> Parser a -> Parser [a]
grouped open delim close item = string open >> body
 where
  body = shut <|> (:) <$> item <*> rest
  rest = many (string delim *> item) <* shut
  shut = string close $> []


-- Rune Helpers ----------------------------------------------------------------

{-
    - If the parser is in `Wide` mode, only accept the `wide` form.
    - If the parser is in `Tall` mode, either
      - accept the `tall` form or:
      - swich to `Wide` mode and then accept the wide form.
-}
parseRune ∷ Parser a → Parser a → Parser a
parseRune tall wide = get >>= \case
  Wide → wide
  Tall → tall <|> inWideMode wide

rune1 ∷ (a→b) → Parser a → Parser b
rune1 node x = parseRune tall wide
  where tall = do gap; p←x;      pure (node p)
        wide = do pal; p←x; par; pure (node p)

rune2 ∷ (a→b→c) → Parser a → Parser b → Parser c
rune2 node x y = parseRune tall wide
  where tall = do gap; p←x; gap; q←y;      pure (node p q)
        wide = do pal; p←x; ace; q←y; par; pure (node p q)

rune3 ∷ (a→b→c→d) → Parser a → Parser b → Parser c → Parser d
rune3 node x y z = parseRune tall wide
  where tall = do gap; p←x; gap; q←y; gap; r←z;      pure (node p q r)
        wide = do pal; p←x; ace; q←y; ace; r←z; par; pure (node p q r)

rune4 ∷ (a→b→c→d→e) → Parser a → Parser b → Parser c → Parser d → Parser e
rune4 node x y z g = parseRune tall wide
  where tall = do gap; p←x; gap; q←y; gap; r←z; gap; s←g; pure (node p q r s)
        wide = do pal; p←x; ace; q←y; ace; r←z; ace; s←g; pure (node p q r s)


-- Entry Point -----------------------------------------------------------------

data Dec = Dec Text AST
  deriving (Show)

decl :: Parser Dec
decl = do
  (n, b) <- string "++" *> rune2 (,) sym exp
  pure (Dec n b)

eat :: Parser ()
eat = option () whitespace

dashFile :: Parser [Dec]
dashFile = do
  hed <- eat *> decl
  tel <- many (try (gap *> decl))
  eat
  eof
  pure (hed : tel)

parseAST ∷ Text → Either Text AST
parseAST txt =
  runParser (evalStateT exp Tall) "stdin" txt & \case
    Left  e → Left (pack $ errorBundlePretty e)
    Right x → pure x

parseDecs ∷ Text → Either Text [Dec]
parseDecs txt =
  runParser (evalStateT dashFile Tall) "stdin" txt & \case
    Left  e → Left (pack $ errorBundlePretty e)
    Right x → pure x


--------------------------------------------------------------------------------

toUruk :: Map Text R.Exp -> AST -> Either Text R.Exp
toUruk env = go
 where
  undef = Left . ("Undefined variable: " <>)
  go = \case
    N v -> lookup v env & maybe (undef v) Right
    x :@ y  -> (R.:@) <$> go x <*> go y

globals :: Map Text R.Exp
globals = mapFromList
  [ ("S", R.N R.S)
  , ("K", R.N R.K)
  , ("J", R.N R.J)
  , ("D", R.N R.D)
  ]

tryExp :: Text -> IO R.Exp
tryExp = (parseAST >=> toUruk globals) >>> \case
  Left err -> putStrLn err >> error ""
  Right ur -> pure ur

tryExec :: R.Exp -> IO R.Exp
tryExec = R.exec >>> go
 where
  go []     = error "impossible"
  go [x]    = print x >> pure x
  go (x:xs) = print x >> go xs

main :: IO ()
main = do
  [txt] <- getArgs
  void (tryExp txt >>= tryExec)
