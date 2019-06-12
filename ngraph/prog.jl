using Pkg; Pkg.activate(".")
using Runner
fex = Runner.test_async()
fex()
fex()
