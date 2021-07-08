#!/bin/sh

cd $(dirname $0)/../../../..
bundle2.7 exec rake reach:enroll_http_pledge PRODUCTID=spec/files/product/00-D0-E5-02-00-2E JRC=https://fountain.local:8443/


