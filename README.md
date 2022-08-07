# Overview
This project is a member of the [CommsChampion Ecosystem](https://commschamp.github.io/).
It provides necessary [CommsDSL](https://commschamp.github.io/commsdsl_spec) schemas as well as
extra injection code to be able to use [ASN.1](https://en.wikipedia.org/wiki/ASN.1) encodings (DER/BER/CER)
in the definition of some binary communication protocols and/or data (de)serialization.

At this stage the work on the available definitions is incomplete. It is performed on-request basis.
If some definition is missing and required for your work, please open an issue, and better yet submit a
pull request with the missing feature implemented.

# How to Build
This project uses CMake as its build system. Please open main
[CMakeLists.txt](CMakeLists.txt) file and review available options as well as mentioned available parameters,
which can be used in addition to standard ones provided by CMake itself, to modify the default build.

The default build without any extra parameters just copies schema files as well as code injection
snippets into the installation directory. Any additions to the build process like unit-testing and/or
extra example applications will require access to the
[COMMS Library](https://github.com/commschamp/comms) and [commsdsl](https://github.com/commschamp/commsdsl)
code generates in its **CMAKE_PREFIX_PATH**.

Default build:
```
$> cd /path/to/cc.asn1.commsdsl
$> mkdir build && cd build
$> cmake .. -DCMAKE_INSTALL_PREFIX=./install
$> cmake --build . --target install
```

Building with apps and tests
```
$> cd /path/to/cc.asn1.commsdsl
$> mkdir build && cd build
$> cmake .. -DCMAKE_INSTALL_PREFIX=./install \
    -DCMAKE_PREFIX_PATH=/path/to/installed/comms/and/commsdsl \
    -DCC_ASN1_BUILD_APPS=ON -DCC_ASN1_BUILD_UNIT_TESTS=ON
$> cmake --build . --target install
```

# How to Use

The installed schema files as well as extra code snippets need to be passed to the [commsdsl](https://github.com/commschamp/commsdsl)
code generator(s) as command line parameters when generating required protocol definition.
Note, that in case the protocol being defined has its own code snippets, that the two code directories
(from this project and the protocol itself) need to be combined into one.

The [tutorial23](https://github.com/commschamp/cc_tutorial/tree/master/tutorials/tutorial23) in the tutorial
project explains how multiple schemas with different names can be used in the protocol definition.

There is main [cc_asn1/dsl/schema.xml](cc_asn1/dsl/schema.xml) file which contains all the available ASN.1 encodings. Definitions
inside this schema can be **&lt;ref&gt;**-erenced directly. The consequence might be having having extra
"cc_asn1" namespace and extra include files.

There is also secondary [cc_asn1/dsl/emb_schema.xml](cc_asn1/dsl/emb_schema.xml) which doesn't specify any name in its
**&lt;schema&gt;** node and intended to be embedded into the actual protocol definition. It
**resuse**-s all the definitions from the [cc_asn1/dsl/schema.xml](cc_asn1/dsl/schema.xml) instead of
**&lt;ref&gt;**-erencing them, resulting in _copying_ all the ASN.1 definitions into the
defined protocol namespace.

In order to use secondary [cc_asn1/dsl/emb_schema.xml](cc_asn1/dsl/emb_schema.xml) the protocol definition needs to
be split into at least 2 schema definition files and they need to be processed by the code
generator(s) in the order specified below:

- [cc_asn1/dsl/schema.xml](cc_asn1/dsl/schema.xml) - Main definitions of this project
- main protocol **&lt;schema&gt;** defining new **name** property.
- [cc_asn1/dsl/emb_schema.xml](cc_asn1/dsl/emb_schema.xml) - Secondary schema of this project to copy all the main schema definition into the protocol namespace
- rest of the protocol **&lt;schema&gt;** definition referencing fields in [cc_asn1/dsl/emb_schema.xml](cc_asn1/dsl/emb_schema.xml).

All the ASN.1 fields need to be encoded as **TLV** (tag-length-value) triplets. They are defined as
**&lt;bundle&gt;** with `Tag`, `Length`, and `Value` fields:
```xml
<bundle name="Boolean">
    <int name="Tag" reuse="TagByte" defaultValidValue="Tag.Boolean" />
    <ref field="der.Length" />
    <int name="Value" type="uint8">
        <special name="False" val="0x0" />
        <special name="True" val="0xff" />
    </int>
</bundle>

<bundle name="Integer" validOverride="extend">
    <int name="Tag" reuse="TagByte" defaultValidValue="Tag.Integer" />
    <ref field="der.Length" />
    <int name="Value" type="int64" availableLengthLimit="true" />
</bundle>
```
It means that the client code usually operates only with the third (`Value`) field, which needs to be accessed
using `field_value()` generated member function:
```
someBoolField.field_value().setTrue(); // Uses generated special value functions
someIntField.field_value().value() = 1234; // Sets value directly
```

Also note that the value of the second field `Length` needs to be updated. It is performed automatically by
invoking the **refresh** functionality after updating the `Value`. It is recommended to invoke
it one time on the root field/message object when all the values are set.
```cpp
msg.someIntField().field_value().value() = 1234;
msg.doRefresh(); // Update all the Length values in all the member fields.
```

The ASN.1 encodings have multiple formats (DER/BER/CER). The provided schema
files define respective inner namespaces (der/ber/cer). At this stage only
DER is implemented and the instructions below is for DER.

## Using BOOLEAN
Using ASN.1 **BOOLEAN** field can be done by referencing **@cc_asn1.der.Boolean** field in external schema
(in case of having **cc_asn1** namespace and extra source files is not a problem) or
referencing **asn1.der.Boolean** in case of [emb_schema.xml](cc_asn1/dsl/emb_schema.xml) is used and
all the ASN.1 definitions need to be copied into the defined protocol namespace (but into
**asn1** second level namespace).

All the subsequent examples will assume that [emb_schema.xml](cc_asn1/dsl/emb_schema.xml) is in use and will
reference fields in the embedded **asn1** namespace.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<schema name="my_prot" endian="big">
    <fields>
        <bundle name="SomeField">
            ...
            <ref field="asn1.der.Boolean" name="SomeMember" />
            ...
        </bundle>
    </fields>
</schema>
```

## Using INTEGER
In cases when the actual integer value fits into regular 64 bit numeric integer type then regular `Integer`
field can be referenced:
```xml
<ref field="asn1.der.Integer" />
```
Its `Value` field is defined as:
```xml
<int name="Value" type="int64" availableLengthLimit="true" />
```
In case the preceding `Length` field reports having 9 bytes or more, only first 8 one will be read to form the value and the rest ignored.

In case when **INTEGER** field is used to define a long number, then the `RawInteger` needs to be used:
```xml
<ref field="asn1.der.RawInteger" />
```
Its `Value` field is defined as:
```xml
<data name="Value" />
```
It's up to the client code the take the read raw data and implement a wrapper around it treating it as a big number.

Note that both `Integer` and `RawInteger` use the same `Tag`
```xml
<int name="Tag" reuse="TagByte" defaultValidValue="Tag.Integer" />
```
As the result it is impossible to differentiate between them. For the cases where use of `Integer` is preferred when possible, and
`RawInteger` when the value is too long there is a definition of `IntegerStrict`. It is the same as `Integer`, but its **read**
operation is expected to fail when the length exceeds 8 bytes, making the constructs like below possible:
```xml
<variant name="SomeUnion">
    ...
    <ref field="asn1.der.IntegerStrict" name="ShortInt" />
    <ref field="asn1.der.RawInteger" name="LongInt" />
    ...
</variant>
```
In the example above `ShortInt` takes precedence and created when encountered, but its **read** operation fails in case the
length is 9 or more bytes, resulting in construction of the `LongInt` instead.

## Defining BIT STRING
In cases when the actual **BIT STRING** value is expected to be no greater than 64 bits, the `BitString` definition
is expected to be **reuse**-d and its `Value` field is replaced with proper **&lt;set&gt;** field definition.
```xml
<bundle name="MyBitstring" reuse="asn1.der.BitString">
    <replace>
        <set name="Value" length="8" availableLengthLimit="true">
            <bit name="B1" idx="1" />
            <bit name="B10" idx="10" />
        </set>
    </replace>
</bundle>
```
Note the usage of **&lt;replace&gt;** node to replace the provided dummy definition of the `Value` field with the
new one relevant to the protocol being defined. Such replacement can be done for any fields, including ones
described above (**BOOLEAN** and **INTEGER**). It can be useful when some **&lt;special&gt;** values need to be
added to the `Value` definition.

In case when **BIT STRING** type is used to define any arbitrary long data field the `RawBitString` is expected to be
used instead. It's `Value` field is defined as:
```xml
<data name="Value" />
```
It's up to the client code to implement a wrapper and provide a convenient access to specific bit if necessary.

Similar to the **INTEGER** case described above there is also `BitStringStrict` when can be used in conjunction with
`RawBitString` when the short form is preferred when applicable but substitution with long form should also be available.

There is another important aspect to the **BIT STRING**. Its binary encoding has special `Shift` prefix byte.
```xml
<int name="Shift" type="uint8" validRange="[0, 7]" />
```
During the **read** operation the encountered `Shift` value specifies the shift of the bit string that follows. After
the **read** operation is complete the actual `Value` will have properly shifted value.

When preparing the **write** operation, the `Shift` field should be updated with **maximal** allowed shift (up to 7 bits)
of the value. The **refresh** operation checks the position of the first non-zero bit inside the stored `Value` and
**reduces** the `Shift` value accordingly. When **write** operation itself is performed it shifts all the written `Value` bits in
accordance with the value specified in `Shift`.

## Other Simple Fields
Other simple field's with a straightforward use that can be **&lt;ref&gt;**-erenced without any modifications are:

- `OctetString` - defines **OCTET STRING**.
- `NULL` - defines **NULL**.
- `Utf8String` - defines **UTF8String**.
- `PrintableString` - defines **PrintableString**.
- `Ia5String` - defines **IA5String**.
- `UtcTime` - defines **UTCTime**.
- `GeneralizedTime` - defines **GeneralizedTime**

## Using OBJECT IDENTIFIER
The **OBJECT IDENTIFIER** is provided by the `ObjectIdentifier` field and can be referenced as-is.
```xml
<ref field="asn1.der.ObjectIdentifier" />
```
It's actual `Value` is defined as a list of integral variable length fields.
```xml
<list name="ObjectIdentifierVal" readOverride="replace" writeOverride="replace" lengthOverride="replace" validOverride="extend">
    <int name="Element" type="uintvar" length="8" />
</list>
```
The serialization of the **OBJECT IDENTIFIER** field needs to unify first two elements into a single value. Such
bundling / un-bundling is performed during the **write** / **read** operations of the field. The client code
doesn't need to worry about such unification.

## Defining SEQUENCE
In order to define a **SEQUENCE**, the provided `Sequence` field is expected to be **reuse**-d and its
`Value` field is expected to be replaced with another **&lt;bundle&gt;** containing all the necessary fields:
```xml
<bundle name="MySequence" reuse="asn1.der.Sequence">
    <replace>
        <bundle name="Value">
            <ref name="F1" field="asn1.der.Integer" />
            <ref name="F2" field="asn1.der.Boolean" />
            <ref name="F3" field="asn1.der.Utf8String" />
            ...
        </bundle>
    </replace>
</bundle>
```

In case of **SEQUENCE OF**, the `Value` member needs to be replaced with a **&lt;list&gt;** rather
than a **&lt;bundle&gt;**. The schema also provides `SequenceOf` field which is the same as `Sequence`, but
uses a dummy **&lt;list&gt;** as its `Value`.
```xml
<bundle name="MySimpleSequenceOf" reuse="asn1.der.SequenceOf">
    <replace>
        <list name="Value" element="asn1.der.Integer" />
    </replace>
</bundle>

<bundle name="MyComplexSequenceOf" reuse="asn1.der.SequenceOf">
    <replace>
        <list name="Value">
            <bundle name="Element">
                <ref name="F1" field="asn1.der.Integer" />
                <ref name="F2" field="asn1.der.Boolean" />
                <ref name="F3" field="asn1.der.Utf8String" />
                ...
            </bundle>
        </list>
    </replace>
</bundle>
```

## Defining SET
In order to define a **SET**, the provided `Set` field is expected to be **reuse**-d and its
`Value` field is expected to be replaced with a **&lt;list&gt;** of **&lt;variant&gt;** field,
which defines all the possible member types
```xml
<bundle name="MySet" reuse="asn1.der.Set">
    <replace>
        <list name="Value">
            <variant name="Element">
                <ref name="F1" field="asn1.der.Boolean" />
                <ref name="F2" field="asn1.der.Integer" />
                <ref name="F3" field="asn1.der.Utf8String" />
                ...
            </variant>
        </list>
    </replace>
</bundle>
```
**IMPORTANT**: The elements inside the **&lt;variant&gt;** field are expected to be in the **ascending** order of the tags.

**ALSO IMPORTANT**: The **SET** field must serialize its elements in the ascending order, i.e. elements must be sorted before
the field is serialized. However, it is impractical to depend on the client code putting the elements into the `Value` list in
the right order. It creates error-prone boilerplate code.
It means that the field needs to be **refresh**-ed before the **write** operation takes place. The **refresh** operation will perform
the required sorting.
```cpp
mySet.field_value().value().resize(3);
mySet.field_value().value[0].initField_f3().field_value().value() = "hello";
mySet.field_value().value[1].initField_f2().field_value().value() = 1234;
mySet.field_value().value[2].initField_f1().field_value().setTrue();
mySet.refresh(); // Sorts the mySet.field_value().value() vector - new order will be f1, f2, f3.
```

The definition of the **SET OF** field is very similar with the list element being a non-**&lt;variant&gt;** one.
```xml
<bundle name="MySetOf" reuse="asn1.der.Set">
    <replace>
        <list name="Value" element="ans1.der.Integer" />
    </replace>
</bundle>
```
Due to the fact that every element in the list has the same tag, the sorting
during the **refresh** functionality is performed using their serialized values, not their tags.

## Optional Fields
The ASN.1 allows having **OPTIONAL** fields which can be present or missing. In order to
define such a field the regular definition must be wrapped in **&lt;optional&gt;** field with
"tentative" **defaultMode** and with **missingOnReadFail** property set to true.
```xml
<optional name="OptionalInt" field="asn1.der.Integer" missingOnReadFail="true" />
```
Usage of the **missingOnReadFail** property insures that the **read** operation doesn't fail
in case the wrong tag is encountered. Instead it marks the **&lt;optional&gt;** field to be
"missing" and proceeds to the next field.

The ASN.1 also allows having **DEFAULT** values, which are **OPTIONAL** and are expected **NOT** to be
serialized when the fields have their default values. The definition of such a field is expected to
have a custom **valid** check functionality reporting its **default** value to be **invalid**. Also
another **missingOnInvalid** property (in addition to **missingOnReadFail**) needs to be set to true.
The **missingOnInvalid** property insures that the **&lt;optional&gt;** field is marked as
"missing" during the **refresh** operation when its value is invalid (happens when it's default).

The example for such a default value definition is `BooleanDefaultFalse` (**BOOLEAN DEFAULT FALSE**) provided by the schemas.
It is defined as:
```xml
<optional name="BooleanDefaultFalse" missingOnReadFail="true" missingOnInvalid="true" validOverride="extend">
    <ref field="der.Boolean" />
</optional>
```
Its injected code for **valid**-ity check operation returns **false** in case the stored boolean value is **false**:
```cpp
bool valid() const
{
    if (!Base::valid()) {
        return false;
    }

    if (Base::isMissing()) {
        return true;
    }

    return !Base::field().field_value().isFalse();
}
```

## Application Tags
In order to create an application field the **&lt;replace&gt;**-ment needs to be performed on the `Tag` field:
```xml
<bundle name="AppInt0" reuse="asn1.der.Integer">
    <replace>
        <int name="Tag" reuse="TagByte" defaultValidValue="Tag.App0" />
    </replace>
</bundle>
```
The `Tag` definition in the schema defines multiple tags with "application" bit set.

## Context Tags
Similar to the "application" tags, the **IMPLICIT** context fields also require replacing the `Tag`:
```xml
<bundle name="ContextInt0" reuse="asn1.der.Integer">
    <replace>
        <int name="Tag" reuse="TagByte" defaultValidValue="Tag.Context0" />
    </replace>
</bundle>
```
The `Tag` definition in the schema defines multiple tags with "context" bit set.

The **EXPLICIT** context fields may require replacing both `Tag` and `Value`. For convenience the
provided schema files define multiple `ExplicitContextX` fields that already replace the `Tag`
leaving only `Value` for replacement.
```xml
<bundle name="ExpContextInt0" reuse="asn1.der.ExplicitContext0">
    <replace>
        <ref name="Value" field="asn1.der.Integer" />
    </replace>
</bundle>
```

# Examples
Below is a list of available examples that use definition of ASN.1 fields from this project to define
their own data structures.

- [cc.x509.commsdsl](https://github.com/commschamp/cc.x509.commsdsl) - Contains definition of the
  [X.509](https://datatracker.ietf.org/doc/html/rfc5280) public key infrastructure certificate.

# License
Please read [License](https://github.com/commschamp/commsdsl#license)
section from [commsdsl](https://github.com/commschamp/commsdsl) project.

# Contact Information
For bug reports, feature requests, or any other question you may open an issue
here in **github** or e-mail me directly to: **arobenko@gmail.com**. I usually
respond within 24 hours.
