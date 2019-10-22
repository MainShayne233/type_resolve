defmodule TypeResolve.Private.SupportingModule do
  @type t :: binary()
end

defmodule TypeResolve.Private.SampleClient do
  alias TypeResolve.Private.SupportingModule, as: Support

  @type status :: :pending | :success | :failure

  @type t :: status()

  @type support :: Support.t()

  @type union :: Support.t() | t()

  @type result :: {:ok, term()} | :error

  @type result(t) :: {:ok, t} | :error

  @typep pemail :: binary()

  @type email :: pemail()

  @type role :: :guest | :user | :admin | [role()]

  @type a :: b()

  @type b :: a()
end

# defmodule MyApp do
#   @type a :: binary()
#   @type b :: atom() | b | [a]
#   @type c :: a | b
# 
#   # resolve(c()) =>
#   {c(),
#    %{
#      c() =>
#        {union(a(), b()),
#         %{
#           a() => {binary(), %{}},
#           b() =>
#             {union(atom(), b(), [a()]),
#              %{
#                union(atom(), b(), [a()]) => {union(atom(), b(), [binary()]), %{}}
#              }},
#           union(a(), b()) => {union(binary(), union(atom(), b(), [binary()])), %{}}
#         }}
#    }}
# end
