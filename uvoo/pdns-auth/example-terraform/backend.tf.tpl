terraform {
backend "pg" {
  conn_str = "{{ PG_CONN_STR }}"
}
}
