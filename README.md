# PathFinder

Path Finder is a module to add a layer of indirection in, or inbetween applications.
A tuple with the following information can be registered to a set of two names.

```
{node | :self, module_name, function_name, argument_list}
```

Registering entry points:

```
defmodule CustomPathFinder do
  use PathFinder
  use PathFinder.Footprints
  
  gatekeeper PipelineModule1
  gatekeeper PipelineModule2
  footprints __MODULE__
  
  footprint :domain1, [
    address1: {:"node1@127.0.0.1", RemoteEntryPoint, :handle_event},
    address2: {:"node1@127.0.0.1", RemoteEntryPoint, :handle_other_event, ["fixed arg"]},
  ]
  
  footprint :domain2, [
    address1: {:"node2@127.0.0.1", RemoveEntryPoint, :handle_event},
  ]
end
```

Finding entry points:

```
CustomPathFinder.follow :domain1, :address1, [arg1, arg2]
|> do_something_with_result
```

Defining a pipeline module

```
defmodule PipelineModule1 do
  use PathFinder.Gatekeeper

  def inspect(next_inspecter) do
    fn state -> apply next_inspecter, [log(state)] end
  end

  def log(state) do
    IO.inspect(state)
    state
  end
end 
```

Note that for communicating with different applications on other nodes, the PathFinder
module must be installed and setup as receiver.

Alternatively you can simply start a Task.Supervisor with the name PathFinder.Destination manually.

## Installation

TODO

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `path_finder` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:path_finder, "~> 0.1.0"}]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/path_finder](https://hexdocs.pm/path_finder).

