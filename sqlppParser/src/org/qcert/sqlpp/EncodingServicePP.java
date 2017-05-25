/**
 * Copyright (C) 2016-2017 Joshua Auerbach 
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package org.qcert.sqlpp;

import org.qcert.javasvc.Command;

/**
 * Link the SQL++ Parser to the javaService so it can be invoked from qcert binary and via http server
 */
public class EncodingServicePP implements Command {
	@Override
	public String invoke(String arg) {
		try {
			return SqlppEncoder.parseAndEncode(arg);
		} catch (Throwable t) {
			return "ERROR: SQL++ Parser said \"" + t.getMessage() + "\"";
		}
	}
}
