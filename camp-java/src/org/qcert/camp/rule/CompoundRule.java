/**
 * Copyright (C) 2016 Joshua Auerbach 
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
package org.qcert.camp.rule;

import java.io.PrintWriter;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Represents a compound rule formed from other FunctionRules 
 */
public final class CompoundRule extends CampRule implements FunctionRule {
	private final List<FunctionRule> members;
	
	public CompoundRule(FunctionRule left, FunctionRule right) {
		ArrayList<FunctionRule> members = new ArrayList<>();
		if (left instanceof CompoundRule)
			members.addAll(((CompoundRule) left).members);
		else
			members.add(left);
		if (right instanceof CompoundRule)
			members.addAll(((CompoundRule) right).members);
		else
			members.add(right);
		this.members = Collections.unmodifiableList(members);
	}
	
	/* (non-Javadoc)
	 * @see org.qcert.camp.CampAST#emit(java.io.PrintWriter)
	 */
	@Override
	public void emit(PrintWriter pw) {
		// TODO Auto-generated method stub
	}

	/* (non-Javadoc)
	 * @see org.qcert.camp.rule.CampRule#getKind()
	 */
	@Override
	public Kind getKind() {
		return Kind.Compound;
	}
}
