
> import System.Environment

> --import Language.Haskell.Exts
> --import Data.Generics.Uniplate.Data

> import Database.HsSqlPpp.Parser
> import GroomUtils
> import Text.Groom
> import qualified Data.Text.Lazy.IO as LT

> main :: IO ()
> main = do
>   [f] <- getArgs
>   src <- LT.readFile f
>   let ast = parseStatements defaultParseFlags
>                {pfDialect = SQLServerDialect} f Nothing src
>   putStrLn $ either groom groomNoAnns ast
