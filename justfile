set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

tf_dir := "terraform"

init:
    terraform -chdir={{tf_dir}} init -backend=false

fmt:
    terraform -chdir={{tf_dir}} fmt -recursive

validate: init
    terraform -chdir={{tf_dir}} validate

check: fmt validate
    git diff --check

clean:
    rm -rf {{tf_dir}}/.terraform
