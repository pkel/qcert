#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

############# Shouldn't have to be changed after this
all: qcert-runtime.js qcert_runtime.ml

qcert-runtime.js: qcert-runtime-core.js qcert-runtime-tostring.js qcert-runtime-sql-date.js qcert-runtime-uri.js
	(for i in qcert-runtime-core.js qcert-runtime-tostring.js qcert-runtime-sql-date.js qcert-runtime-uri.js; do \
         cat $$i; \
         done) > qcert-runtime.js

qcert_runtime.ml: qcert-runtime.js
	(echo "let runtime = {runtime|"; \
         cat qcert-runtime.js; \
         echo '|runtime}' \
         ) > qcert_runtime.ml

clean:
	-rm -f qcert-runtime.js qcert_runtime.ml
	-rm -f *~

cleanall: clean

