.DEFAULT_GOAL = help
PROJECT_NAME = boilerplatepython
export POETRY_VIRTUALENVS_IN_PROJECT = true

## Dependencies

poetry.lock: _HELP = Lock dependency versions to file
poetry.lock:
	poetry lock

.PHONY: deps
deps: _HELP = Install project dependencies
deps:
	poetry install -E docs
	poetry run python -V

requirements.txt: _HELP = Generate development requirements.txt
requirements.txt: poetry.lock
	poetry export --dev --without-hashes -o $@

## Testing

.PHONY: lint
lint: _HELP = Run linters
lint: deps
	poetry check
	poetry run black --check --color --diff .
	poetry run flake8 --application-import-names $(PROJECT_NAME),tests
	poetry run pylint $(PROJECT_NAME) tests docs/conf.py

.PHONY: test
test: _HELP = Run unit tests
test: deps
	poetry run pytest --cov=$(PROJECT_NAME) --cov-report=html --cov-report=xml tests/unit_tests

.PHONY: testpdb
testpdb: _HELP = Run unit tests and drop into the debugger on failure
testpdb: deps
	poetry run pytest --pdb tests/unit_tests

.PHONY: it
it: _HELP = Run integration tests
it: deps
	poetry run pytest tests/integration_tests

.PHONY: itpdb
itpdb: _HELP = Run integration tests and drop into the debugger on failure
itpdb: deps
	poetry run pytest --pdb tests/integration_tests

.PHONY: all
all: _HELP = Run linters, unit tests, integration tests, and builds
all: lint test it docs build

## Build

.PHONY: build
build: _HELP = Build Python package (sdist and wheel)
build:
	poetry build -n -vvv

docs/_build/html/index.html: deps
	poetry run sphinx-build -a -E -n -W docs $(@D)
	@echo Documentation available here: $@

.PHONY: docs
docs: _HELP = Build HTML documentation
docs: docs/_build/html/index.html

## Misc

clean: _HELP = Remove temporary files
clean:
	rm -rfv *.egg-info/ *cache*/ .*cache*/ .coverage coverage.xml htmlcov/ dist/ docs/_build requirements.txt
	find . -name __pycache__ -type d -exec rm -r {} +

distclean: _HELP = Remove temporary files including virtualenv
distclean: clean
	rm -rf .venv/

define MAKEFILE_HELP_AWK
BEGIN {
	while (getline < "/dev/stdin") if ($$0 == "# Files") break  # Skip lines until targets start being listed.
	while (getline < "/dev/stdin") {
		if ($$0 ~ /^# makefile \(from [`']/ && match($$0, /', line [0-9]+\)$$/)) {
			file_name = substr($$0, 19, RSTART - 19)
			line_no = substr($$0, RSTART + 8, RLENGTH - 8 - 1)
		} else if (match($$0, /^# _HELP = /) || match($$0, /^[^ \t#:]+: _HELP = /)) {
			help = substr($$0, RLENGTH + 1)
			if (RLENGTH > 10) target_name = $$1  # make 4.x
			if (file_name && line_no && target_name && help) {  # Commit to data array if all states are set.
				for (i = 0; file_name SUBSEP line_no SUBSEP i SUBSEP "target_name" in data; i++) {}  # Just increment i.
				data[file_name,line_no,i,"target_name"] = target_name
				data[file_name,line_no,i,"help"] = help
				if (length(target_name) > data["width"]) data["width"] = length(target_name)
				$$0 = ""  # Signal to clear state.
			}
		} else if (match($$0, /^[^ \t#:]+:/)) target_name = $$1  # make 3.
		if (!$$0) file_name = line_no = target_name = help = ""  # Reset state on blank line.
	}

	data["width"] += col1pad + 0  # Adding 0 initializes to int.
	if (col1minwidth + 0 > data["width"]) data["width"] = col1minwidth
	if (col1tab + 0 && (remainder = data["width"] % col1tab)) data["width"] += (col1tab - remainder)

	cyan    = (colors == "true") ? "\033[36m" : ""
	magenta = (colors == "true") ? "\033[35m" : ""
	reset   = (colors == "true") ? "\033[00m" : ""
}

match($$0, /^[ \t]*##[ \t]*[^ \t#]/) {
	gsub(/[ \t]+$$/, "")  # Strip trailing whitespace.
	header = substr($$0, RLENGTH)
}

FILENAME SUBSEP FNR SUBSEP 0 SUBSEP "target_name" in data {
	if (header) { print magenta header ":" reset; header = "" }
	target_fmt = "%-" data["width"] "s"
	for (i = 0; FILENAME SUBSEP FNR SUBSEP i SUBSEP "target_name" in data; i++) {
		printf(cyan target_fmt reset "%s\n", data[FILENAME,FNR,i,"target_name"], data[FILENAME,FNR,i,"help"])
	}
}
endef

help: make_workaround = $(MAKE)
help: export program = $(MAKEFILE_HELP_AWK)
help: _HELP = Print help menu
help:
	@($(make_workaround) -qprR $(foreach f,$(MAKEFILE_LIST),-f $(f)) 2>/dev/null || true) |awk -F : \
		-v "col1minwidth=$(or $(HELP_WIDTH),16)" \
		-v "col1tab=$(or $(HELP_TAB),4)" \
		-v "col1pad=$(or $(HELP_PAD),2)" \
		-v "colors=$(or $(HELP_COLORS),true)" \
		"$$program" $(MAKEFILE_LIST)
