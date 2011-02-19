
> module Database.HsSqlPpp.Tests.Tests (allTests) where
>
> import Test.Framework
>
> import Database.HsSqlPpp.Tests.ParserTests
> --import Database.HsSqlPpp.Tests.FixUpIdentifiersTests
> --import Database.HsSqlPpp.Tests.TypeCheckTests
> --import Database.HsSqlPpp.Tests.TpchTests
> {-import Database.HsSqlPpp.Extensions.ExtensionTests
> import Database.HsSqlPpp.Tests.ParameterizedStatementTests
> --import Database.HsSqlPpp.Tests.RoundtripTests
> import Database.HsSqlPpp.Tests.LocalBindingsTests
> import Database.HsSqlPpp.Tests.QuasiQuoteTests
> import Database.HsSqlPpp.Tests.TypeInferenceTests
> import Database.HsSqlPpp.Tests.BindingsTests-}
> --import Database.HsSqlPpp.Tests.TypeChecking.TableRefTests
>
> allTests :: [Test]
> allTests =
>     parserTests : [] {-
>     fixUpIdentifiersTests :
>     tableRefTests : []
>     --typeCheckTests :
>     --tpchTests : []
>     extensionTests :
>     quasiQuoteTests :
>     typeInferenceTests :
>     bindingsTests :
>     parameterizedStatementTests ++
>     --roundtripTests ++
>     localBindingsTests -}
