#include <nan.h>
#include <unicode/unistr.h>
#include <unicode/usprep.h>
#include <unicode/uidna.h>
#include <cstring>
#include <exception>

using namespace v8;
using namespace node;

/* supports return of just enum */
class UnknownProfileException : public std::exception {
};

// protect constructor from GC
static Persistent<FunctionTemplate> stringprep_constructor;

class StringPrep : public ObjectWrap {
public:
  static void Initialize(Handle<Object> target)
  {
    NanScope();
    Local<FunctionTemplate> t = FunctionTemplate::New(New);
    NanAssignPersistent(FunctionTemplate, stringprep_constructor, t);
    t->InstanceTemplate()->SetInternalFieldCount(1);
    NODE_SET_PROTOTYPE_METHOD(t, "prepare", Prepare);

    target->Set(String::NewSymbol("StringPrep"), t->GetFunction());
  }

  bool good() const
  {
    return U_SUCCESS(error);
  }

  const char *errorName() const
  {
    return u_errorName(error);
  }

protected:
  /*** Constructor ***/

  static NAN_METHOD(New)
  {
    NanScope();

    if (args.Length() >= 1 && args[0]->IsString())
      {
        String::Utf8Value arg0(args[0]->ToString());
        UStringPrepProfileType profileType;
        try
          {
            profileType = parseProfileType(arg0);
          }
        catch (UnknownProfileException &)
          {
            NanThrowTypeError("Unknown StringPrep profile");
            NanReturnUndefined();
          }

        StringPrep *self = new StringPrep(profileType);
        if (self->good())
          {
            self->Wrap(args.This());
            NanReturnValue(args.This());
          }
        else
          {
            const char* err = self->errorName();
            delete self;
            NanThrowError(err);
            NanReturnUndefined();
          }
      }
    else {
      NanThrowTypeError("Bad argument.");
      NanReturnUndefined();
    }
  }

  StringPrep(const UStringPrepProfileType profileType)
    : error(U_ZERO_ERROR)
  {
    profile = usprep_openByType(profileType, &error);
  }

  /*** Destructor ***/

  ~StringPrep()
  {
    if (profile)
      usprep_close(profile);
  }

  /*** Prepare ***/

  static NAN_METHOD(Prepare)
  {
    NanScope();

    if (args.Length() >= 1 && args[0]->IsString())
      {
        StringPrep *self = ObjectWrap::Unwrap<StringPrep>(args.This());
        String::Value arg0(args[0]->ToString());
        NanReturnValue(self->prepare(arg0));
      }
    else {
      NanThrowTypeError("Bad argument.");
      NanReturnUndefined();
    }
  }

  Handle<Value> prepare(String::Value &str)
  {
    size_t destLen = str.length() + 1;
    UChar *dest = NULL;
    while(!dest)
      {
        error = U_ZERO_ERROR;
        dest = new UChar[destLen];
        size_t w = usprep_prepare(profile,
                                  *str, str.length(),
                                  dest, destLen,
                                  USPREP_DEFAULT, NULL, &error);

        if (error == U_BUFFER_OVERFLOW_ERROR)
          {
            // retry with a dest buffer twice as large
            destLen *= 2;
            delete[] dest;
            dest = NULL;
          }
        else if (!good())
          {
            // other error, just bail out
            delete[] dest;
            NanThrowError(errorName());
            return v8::Undefined();
          }
        else
          destLen = w;
      }

    Local<String> result = String::New(dest, destLen);
    delete[] dest;
    return result;
  }

private:
  UStringPrepProfile *profile;
  UErrorCode error;

  static enum UStringPrepProfileType parseProfileType(String::Utf8Value &profile)
    throw(UnknownProfileException)
  {
    if (strcasecmp(*profile, "nameprep") == 0)
      return USPREP_RFC3491_NAMEPREP;
    if (strcasecmp(*profile, "nfs4_cs_prep") == 0)
      return USPREP_RFC3530_NFS4_CS_PREP;
    if (strcasecmp(*profile, "nfs4_cs_prep") == 0)
      return USPREP_RFC3530_NFS4_CS_PREP_CI;
    if (strcasecmp(*profile, "nfs4_cis_prep") == 0)
      return USPREP_RFC3530_NFS4_CIS_PREP;
    if (strcasecmp(*profile, "nfs4_mixed_prep prefix") == 0)
      return USPREP_RFC3530_NFS4_MIXED_PREP_PREFIX;
    if (strcasecmp(*profile, "nfs4_mixed_prep suffix") == 0)
      return USPREP_RFC3530_NFS4_MIXED_PREP_SUFFIX;
    if (strcasecmp(*profile, "iscsi") == 0)
      return USPREP_RFC3722_ISCSI;
    if (strcasecmp(*profile, "nodeprep") == 0)
      return USPREP_RFC3920_NODEPREP;
    if (strcasecmp(*profile, "resourceprep") == 0)
      return USPREP_RFC3920_RESOURCEPREP;
    if (strcasecmp(*profile, "mib") == 0)
      return USPREP_RFC4011_MIB;
    if (strcasecmp(*profile, "saslprep") == 0)
      return USPREP_RFC4013_SASLPREP;
    if (strcasecmp(*profile, "trace") == 0)
      return USPREP_RFC4505_TRACE;
    if (strcasecmp(*profile, "ldap") == 0)
      return USPREP_RFC4518_LDAP;
    if (strcasecmp(*profile, "ldapci") == 0)
      return USPREP_RFC4518_LDAP_CI;

    throw UnknownProfileException();
  }
};


/*** IDN support ***/

NAN_METHOD(ToUnicode)
{
  NanScope();

  if (args.Length() >= 1 && args[0]->IsString())
  {
    String::Value str(args[0]->ToString());
    // ASCII encoding (xn--*--*) should be longer than Unicode
    size_t destLen = str.length() + 1;
    UChar *dest = NULL;
    while(!dest)
      {
        dest = new UChar[destLen];
        UErrorCode error = U_ZERO_ERROR;
        size_t w = uidna_toUnicode(*str, str.length(),
                                   dest, destLen,
                                   UIDNA_DEFAULT,
                                   NULL, &error);
        
        if (error == U_BUFFER_OVERFLOW_ERROR)
          {
            // retry with a dest buffer twice as large
            destLen *= 2;
            delete[] dest;
            dest = NULL;
          }
        else if (U_FAILURE(error))
          {
            // other error, just bail out
            delete[] dest;
            NanThrowError(u_errorName(error));
            NanReturnUndefined();
          }
        else
          destLen = w;
      }

    Local<String> result = String::New(dest, destLen);
    delete[] dest;
    NanReturnValue(result);
  }
  else {
    NanThrowTypeError("Bad argument.");
    NanReturnUndefined();
  }
}



/*** Initialization ***/

extern "C" void init(Handle<Object> target)
{
  NanScope();
  StringPrep::Initialize(target);
  NODE_SET_METHOD(target, "toUnicode", ToUnicode);
}

NODE_MODULE(node_stringprep, init)
