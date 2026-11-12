## ----include = FALSE----------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  eval = rlang::is_installed(c(
    "admiral", "callr", "covr", "dplyr", "pharmaverseadam", "tibble", "tidyr"
  ))
)
withr::local_options(mighty.component.verbosity_level = "quiet")

## ----setup--------------------------------------------------------------------
library(mighty.component)

## ----list-components----------------------------------------------------------
path <- system.file("examples", package = "mighty.component")
list_components(path)

## ----get-ady------------------------------------------------------------------
ady <- get_component(
  system.file("examples", "ady.mustache", package = "mighty.component")
)
ady

## ----inspect-fields-----------------------------------------------------------
ady$id
ady$title
ady$type
ady$params
ady$depends
ady$outputs
ady$origin
ady$method

## ----render-ady---------------------------------------------------------------
ady_rendered <- ady$render(domain = "ADAE", variable = "ASTDY", date = "ASTDT")
ady_rendered

## ----shortcut-----------------------------------------------------------------
get_rendered_component(
  system.file("examples", "ady.mustache", package = "mighty.component"),
  list(domain = "ADAE", variable = "ASTDY", date = "ASTDT")
)

## ----render-error, error=TRUE-------------------------------------------------
try({
ady$render(domain = "ADAE")
})

## ----eval-setup---------------------------------------------------------------
ADAE <- pharmaverseadam::adae |>
  dplyr::select(USUBJID, ASTDT, TRTSDT)

names(ADAE)

## ----eval-run-----------------------------------------------------------------
ady_rendered$eval()
names(ADAE)
head(ADAE)

## ----stream-example-----------------------------------------------------------
script_file <- tempfile(fileext = ".R")
ady_rendered$stream(script_file)
readLines(script_file)

## ----custom-write, include = FALSE--------------------------------------------
r2base_file <- file.path(withr::local_tempdir(), "r2base.mustache")
writeLines(c(
  "#' @title Ratio to baseline",
  "#' @description",
  "#' Derives the ratio of the analysis value to the baseline value.",
  "#'",
  "#' @param domain `character` Name of the domain",
  "#' @param variable `character` Name of the new ratio variable",
  "#' @type column",
  "#' @origin Derived",
  "#' @method Ratio of AVAL to BASE",
  "#' @depends {{{domain}}} AVAL",
  "#' @depends {{{domain}}} BASE",
  "#' @outputs {{{variable}}}",
  "#' @code",
  "{{{domain}}} <- {{{domain}}} |>",
  "  dplyr::mutate(",
  "    {{{variable}}} = dplyr::if_else(BASE != 0, AVAL / BASE, NA_real_)",
  "  )"
), r2base_file)

## ----custom-load--------------------------------------------------------------
r2base <- get_component(r2base_file)
r2base

## ----custom-render------------------------------------------------------------
r2base_rendered <- r2base$render(
  domain = "ADLB",
  variable = "R2BASE"
)
r2base_rendered$code

## ----custom-eval--------------------------------------------------------------
ADLB <- pharmaverseadam::adlb |>
  dplyr::filter(PARAMCD == "ALB") |>
  dplyr::select(USUBJID, PARAMCD, AVISIT, AVAL, BASE)

head(ADLB)

r2base_rendered$eval()

ADLB |>
  dplyr::select(USUBJID, PARAMCD, AVISIT, AVAL, BASE, R2BASE) |>
  head()

## ----repos-setup--------------------------------------------------------------
examples <- system.file("examples", package = "mighty.component")
team_repo <- tempfile("team")
dir.create(team_repo)
invisible(file.copy(r2base_file, team_repo))

ady_template <- readLines(file.path(examples, "ady.mustache"))
ady_template[[1]] <- "#' @title Analysis relative day (team version)"
writeLines(ady_template, file.path(team_repo, "ady.mustache"))

## ----repos-priority-----------------------------------------------------------
repos <- c(team_repo, examples)
list_components(repos)
get_component("ady", repos = repos)$title

## ----repos-reverse------------------------------------------------------------
get_component("ady", repos = rev(repos))$title

## ----repos-not-found, error = TRUE--------------------------------------------
try({
is.null(find_component("adt", repos = repos))
get_component("adt", repos = repos)
})

## ----repos-tibble-------------------------------------------------------------
list_components(repos, as = "tibble") |>
  dplyr::select(id, title, type, origin)

## ----repos-github, eval = FALSE-----------------------------------------------
# repos <- mighty_repos(c(
#   "github::NovoNordisk-OpenSource/mighty.standards/components@main",
#   paste0(
#     "url::https://raw.githubusercontent.com/",
#     "NovoNordisk-OpenSource/mighty.standards/main/components"
#   ),
#   examples
# ))
# get_component("dummy", repos = repos)

## ----validation-fail-setup, include = FALSE-----------------------------------
bad_template <- c(
  "#' @title Bad join example",
  "#' @description Implicit join that will fail validation.",
  "#'",
  "#' @param domain `character` Name of the domain",
  "#' @type row",
  "#' @origin Derived",
  "#' @method Implicit join on other_data",
  "#' @depends {{{domain}}} USUBJID",
  "#' @outputs MYCOL",
  "#' @code",
  "{{{domain}}} <- {{{domain}}} |>",
  "  dplyr::left_join(other_data)"
)

bad_file <- withr::local_tempfile(fileext = ".mustache", lines = bad_template)

## ----validation-fail, error=TRUE----------------------------------------------
try({
get_rendered_component(bad_file, list(domain = "ADAE"))
})

## ----validation-pass-setup, include = FALSE-----------------------------------
good_template <- c(
  "#' @title Good join example",
  "#' @description Explicit join that passes validation.",
  "#'",
  "#' @param domain `character` Name of the domain",
  "#' @type row",
  "#' @origin Derived",
  "#' @method Explicit join on other_data by USUBJID",
  "#' @depends {{{domain}}} USUBJID",
  "#' @outputs MYCOL",
  "#' @code",
  "{{{domain}}} <- {{{domain}}} |>",
  "  dplyr::left_join(other_data, by = dplyr::join_by(USUBJID))"
)

good_file <- withr::local_tempfile(fileext = ".mustache", lines = good_template)

## ----validation-pass----------------------------------------------------------
get_rendered_component(good_file, list(domain = "ADAE"))$code

## ----test-create--------------------------------------------------------------
ady_path <- system.file(
  "examples", "ady.mustache",
  package = "mighty.component"
)
ady_test <- get_test_component(
  component = ady_path,
  params = list(domain = "ADAE", variable = "ASTDY", date = "ASTDT"),
  check_coverage = FALSE # keep the default TRUE in tests
)
ady_test

## ----test-assign--------------------------------------------------------------
adae_input <- pharmaverseadam::adae |>
  dplyr::select(USUBJID, ASTDT, TRTSDT)

ady_test$assign("ADAE", adae_input)
ady_test$ls()

## ----test-eval----------------------------------------------------------------
ady_test$eval()
ady_test$get("ADAE") |> head()

## ----test-coverage------------------------------------------------------------
# Print method
ady_test
# Percent coverage
ady_test$percent_coverage
# Line coverage as a data.frame
ady_test$line_coverage

## ----cleanup, include = FALSE-------------------------------------------------
ady_test$close()
unlink(c(script_file, team_repo), recursive = TRUE)

