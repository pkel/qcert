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
package org.qcert.camp.pattern;

import org.qcert.camp.CampAST;


/**
 * Represents all Patterns (expressions in CAMP rather than Rules or Data)
 */
public abstract class CampPattern extends CampAST {
	public enum Kind {
		  pconst, punop, pbinop, pmap, passert, 
		  porElse, pit, pletIt, pgetconstant, penv, 
		  pletEnv, pleft, pright; 
	}
	
	private final CampPattern[] operands;
	
	protected CampPattern(CampPattern ... operands) {
		this.operands = operands;
	}
	
	public abstract Kind getKind();
	
	public CampPattern getOperand() {
		return getOperand1();
	}
	
	public CampPattern getOperand1() {
		return operands[0];
	}
	
	public CampPattern getOperand2() {
		return operands[1];
	}
}
