MODULE = CryptX         PACKAGE = Crypt::Mode::ECB

PROTOTYPES: DISABLE

### BEWARE - GENERATED FILE, DO NOT EDIT MANUALLY!

Crypt::Mode::ECB
new(Class, char * cipher_name, int padding=1, int rounds=0)
    CODE:
    {
        Newz(0, RETVAL, 1, struct ecb_struct);
        if (!RETVAL) croak("FATAL: Newz failed");
        RETVAL->padding_mode = padding;
        RETVAL->padlen = 0;
        RETVAL->direction = 0;
        RETVAL->cipher_rounds = rounds;
        RETVAL->cipher_id = _find_cipher(cipher_name);
        if (RETVAL->cipher_id == -1) {
          Safefree(RETVAL);
          croak("FATAL: find_cipfer failed for '%s'", cipher_name);
        }
    }
    OUTPUT:
        RETVAL

void
DESTROY(Crypt::Mode::ECB self)
    CODE:
        Safefree(self);

void
start_decrypt(Crypt::Mode::ECB self, SV * key)
    ALIAS:
        start_encrypt = 1
    PPCODE:
    {
        int rv;
        STRLEN k_len=0;
        unsigned char *k=NULL;

        if (!SvPOK(key))   croak("FATAL: key must be string/buffer scalar");
        k = (unsigned char *) SvPVbyte(key, k_len);

        rv = ecb_start(self->cipher_id, k, (unsigned long)k_len, self->cipher_rounds, &self->state);
        if (rv != CRYPT_OK) {
          croak("FATAL: ecb_start failed: %s", error_to_string(rv));
        }

        self->direction = ix == 1 ? 1 : -1;
        self->padlen = 0;
        XPUSHs(ST(0)); /* return self */
    }

SV *
add(Crypt::Mode::ECB self, ...)
    CODE:
    {
        int rv, has_tmp_block, blen, j;
        unsigned long i;
        STRLEN in_data_len, in_data_start, out_len = 0;
        unsigned char *in_data, *out_data, tmp_block[MAXBLOCKSIZE];

        RETVAL = newSVpvn("", 0);
        for (j = 1; j < items; j++) {
          in_data = (unsigned char *)SvPVbyte(ST(j), in_data_len);
          blen = (&self->state)->blocklen;
          in_data_start = 0;
          has_tmp_block = 0;
          if (in_data_len > 0) {
            if (self->direction == 1) {
              /* handle non-empty self->pad buffer */
              if (self->padlen > 0) {
                i = (blen - self->padlen);
                if (in_data_len >= i) { /* enough data to fill pad */
                  Copy(in_data, self->pad+self->padlen, i, unsigned char);
                  in_data_len -= i;
                  in_data_start = i;
                  rv = ecb_encrypt(self->pad, tmp_block, blen, &self->state);
                  if (rv != CRYPT_OK) {
                    SvREFCNT_dec(RETVAL);
                    croak("FATAL: ecb_encrypt failed: %s", error_to_string(rv));
                  }
                  self->padlen = 0;
                  has_tmp_block = 1;
                }
                else { /* not enough data to fill pad */
                  Copy(in_data, self->pad+self->padlen, in_data_len, unsigned char);
                  self->padlen += (int)in_data_len;
                  in_data_len = 0;
                }
              }

              i = (unsigned long)(in_data_len % blen);
              if (in_data_len > 0 && i > 0) { /* save tail of data into pad */
                Copy(in_data + in_data_start + in_data_len - i, self->pad, i, unsigned char);
                self->padlen = i;
                in_data_len -= i;
              }

              if (in_data_len > 0) {
                i = (unsigned long)(has_tmp_block ? in_data_len + blen : in_data_len);
                out_data = (unsigned char*)SvGROW(RETVAL, out_len + i + 1) + out_len;
                out_len += i;
                if (has_tmp_block) {
                  Copy(tmp_block, out_data, blen, unsigned char);
                  out_data += blen;
                }
                rv = ecb_encrypt(in_data+in_data_start, out_data, (unsigned long)in_data_len, &self->state);
                if (rv != CRYPT_OK) {
                  SvREFCNT_dec(RETVAL);
                  croak("FATAL: ecb_encrypt failed: %s", error_to_string(rv));
                }
              } /* in_data_len > 0 */
              else if (has_tmp_block) {
                out_data = (unsigned char*)SvGROW(RETVAL, out_len + blen + 1) + out_len;
                out_len += blen;
                Copy(tmp_block, out_data, blen, unsigned char);
              }
            }
            else if (self->direction == -1) {
              if (self->padlen == blen) {
                rv = ecb_decrypt(self->pad, tmp_block, blen, &self->state);
                if (rv != CRYPT_OK) {
                  SvREFCNT_dec(RETVAL);
                  croak("FATAL: ecb_decrypt failed: %s", error_to_string(rv));
                }
                self->padlen = 0;
                has_tmp_block = 1;
              } /* padlen == blen */
              else if (self->padlen > 0) {
                i = (blen - self->padlen); /* remaining bytes in padding buffer */
                if (in_data_len >= i) { /* enough data to fill pad */
                  Copy(in_data, self->pad+self->padlen, i, unsigned char);
                  self->padlen += i;
                  in_data_len -= i;
                  in_data_start = i;
                  if (in_data_len>0 || self->padding_mode == 0) {
                    rv = ecb_decrypt(self->pad, tmp_block, blen, &self->state);
                    if (rv != CRYPT_OK) {
                      SvREFCNT_dec(RETVAL);
                      croak("FATAL: ecb_decrypt failed: %s", error_to_string(rv));
                    }
                    self->padlen = 0;
                    has_tmp_block = 1;
                  }
                }
                else { /* not enough data to fill pad */
                  Copy(in_data, self->pad+self->padlen, in_data_len, unsigned char);
                  self->padlen += (int)in_data_len;
                  in_data_len = 0;
                }
              } /* padlen > 0 */

              /* here: a/ padlen == 1..16 && in_data_len == 0; b/ padlen == 0 && in_data_len > 0 */
              if (in_data_len>0) {
                i = (unsigned long)(in_data_len % blen);
                if (i>0) { /* save tail of data into pad */
                  Copy(in_data+in_data_start+in_data_len-i, self->pad, i, unsigned char);
                  self->padlen = i;
                  in_data_len -= i;
                }
              }

              if (in_data_len>0) {
                if (self->padlen == 0 && self->padding_mode !=0) {
                  /* in case of padding keep full pad if no more data */
                  Copy(in_data+in_data_start+in_data_len-blen, self->pad, blen, unsigned char);
                  self->padlen = blen;
                  in_data_len -= blen;
                }
                i = (unsigned long)(has_tmp_block ? in_data_len + blen : in_data_len);
                if (i > 0) {
                  out_data = (unsigned char*)SvGROW(RETVAL, out_len + i + 1) + out_len;
                  out_len += i;
                  if (has_tmp_block) {
                    Copy(tmp_block, out_data, blen, unsigned char);
                    out_data += blen;
                  }
                  rv = ecb_decrypt(in_data+in_data_start, out_data, (unsigned long)in_data_len, &self->state);
                  if (rv != CRYPT_OK) {
                    SvREFCNT_dec(RETVAL);
                    croak("FATAL: ecb_decrypt failed: %s", error_to_string(rv));
                  }
                }
              } /* in_data_len>0 */
              else if (has_tmp_block) {
                out_data = (unsigned char*)SvGROW(RETVAL, out_len + blen + 1) + out_len;
                out_len += blen;
                Copy(tmp_block, out_data, blen, unsigned char);
              }
            }
            else {
              SvREFCNT_dec(RETVAL);
              croak("FATAL: call start_decryt or start_encrpyt first (%d)", self->direction);
            }
          }
        }
        if (out_len > 0) SvCUR_set(RETVAL, out_len);
    }
    OUTPUT:
        RETVAL

SV *
finish(Crypt::Mode::ECB self)
    CODE:
    {
        unsigned char tmp_block[MAXBLOCKSIZE], ch;
        int i, j, rv, blen = (&self->state)->blocklen;

        if (self->direction == 1) {
          if (self->padlen<0 || self->padlen>=blen) croak("FATAL: invalid padlen");
          if (self->padding_mode == 1) { /* pkcs5|7 padding */
            i = blen - self->padlen;
            if (i == 0) i = blen;
            for(j=self->padlen; j<blen; j++) self->pad[j] = (unsigned char)i;
            rv = ecb_encrypt(self->pad, tmp_block, blen, &self->state);
            if (rv != CRYPT_OK) croak("FATAL: ecb_encrypt failed: %s", error_to_string(rv));
          }
          else if (self->padding_mode == 2) { /* oneandzeroes padding */
            self->pad[self->padlen] = 0x80;
            for(j=self->padlen+1; j<blen; j++) self->pad[j] = 0;
            rv = ecb_encrypt(self->pad, tmp_block, blen, &self->state);
            if (rv != CRYPT_OK) croak("FATAL: ecb_encrypt failed: %s", error_to_string(rv));
          }
          else {
            if (self->padlen>0) croak("FATAL: ecb_encrypt, input data length not multiple of %d", blen);
            blen = 0;
          }
        }
        else if (self->direction == -1) {
          if (self->padlen > 0) {
            if (self->padlen != blen) croak("FATAL: cipher text length has to be multiple of %d (%d)", blen, self->padlen);
            rv = ecb_decrypt(self->pad, tmp_block, blen, &self->state);
            if (rv != CRYPT_OK) croak("FATAL: ecb_decrypt failed: %s", error_to_string(rv));
            if (self->padding_mode == 0) {         /* no padding */
              /* we already have blen */
            }
            else if (self->padding_mode == 1) {    /* pkcs5|7 padding */
              ch = tmp_block[blen-1];
              blen = blen - (ch > blen ? blen : ch);
            }
            else if (self->padding_mode == 2) {    /* oneandzeroes padding */
              while ((unsigned char)tmp_block[blen - 1] == 0x00) blen--;
              if ((unsigned char)tmp_block[blen - 1] == 0x80) blen--;
              if (blen < 0) blen = 0;
            }
          }
          else {
            blen = 0;
          }
        }
        else {
           XSRETURN_UNDEF;
        }

        self->direction = 0;
        RETVAL = newSVpvn((char*)tmp_block, blen);
    }
    OUTPUT:
        RETVAL
