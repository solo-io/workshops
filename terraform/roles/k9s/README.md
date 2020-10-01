# aries1980.k9s

Ansible role to install the [k9s](https://k9ss.io/) Kubernetes terminal tool.


# Requirements

See [meta/main.yml](meta/main.yml).


# Role Variables

See [defaults/main.yml](defaults/main.yml) and [defaults/Windows.yml](defaults/Windows.yml).
In case you want to keep the misc files of k9s in the installation directory, you need to add
`k9s_excluded_files: ""` as a role parameter.


# Dependencies

See [meta/main.yml](meta/main.yml)


# Example Playbook

```yml
- hosts: laptop
  roles:
    - aries1980.k9s
```
