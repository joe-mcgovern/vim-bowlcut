# pbgo

This project was created because of a problem I had been running into at work.
We were generating some code, which would result in definitions like 
`ExecuteWorkflowFetchResource`. Clients would call these functions. However, jumping
to that function definition would only go to the auto-generated code, which was
undesirable. There was an actual implementation of `FetchResource` somewhere and
that is what I was wanting to jump to, not the wrapping function.

The way this works is that it will first attempt to 

## TODOS

* Support signal definitions
* Drop fzf dependency
* Drop ripgrep dependency
