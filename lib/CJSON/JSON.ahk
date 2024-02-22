#Requires AutoHotkey v2.0

class JSON
{
	static version := "2.0.0-git-dev"

	static BoolsAsInts {
		get => this.lib.bBoolsAsInts
		set => this.lib.bBoolsAsInts := value
	}

	static NullsAsStrings {
		get => this.lib.bNullsAsStrings
		set => this.lib.bNullsAsStrings := value
	}

	static EscapeUnicode {
		get => this.lib.bEscapeUnicode
		set => this.lib.bEscapeUnicode := value
	}

	static fnCastString := Format.Bind('{}')

	static Load(json) {
		_json := " " json ; Prefix with a space to provide room for BSTR prefixes
		pJson := Buffer(A_PtrSize)
		NumPut("Ptr", StrPtr(_json), pJson)

		pResult := Buffer(24)

		if r := this.lib.loads(pJson, pResult)
		{
			throw Error("Failed to parse JSON (" r ")", -1
			, Format("Unexpected character at position {}: '{}'"
			, (NumGet(pJson, 'UPtr') - StrPtr(_json)) // 2, Chr(NumGet(NumGet(pJson, 'UPtr'), 'Short'))))
		}

		result := ComValue(0x400C, pResult.Ptr)[] ; VT_BYREF | VT_VARIANT
		if IsObject(result)
			ObjRelease(ObjPtr(result))
		return result
	}

	static True {
		get {
			static _ := {value: true, name: 'true'}
			return _
		}
	}

	static False {
		get {
			static _ := {value: false, name: 'false'}
			return _
		}
	}

	static Null {
		get {
			static _ := {value: '', name: 'null'}
			return _
		}
	}
}
