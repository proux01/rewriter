.SUFFIXES:

MOD_NAME := Crypto
SRC_DIR  := src
TIMED?=
TIMECMD?=
STDTIME?=/usr/bin/time -f "$* (real: %e, user: %U, sys: %S, mem: %M ko)"
TIMER=$(if $(TIMED), $(STDTIME), $(TIMECMD))

PROFILE?=
VERBOSE?=
SHOW := $(if $(VERBOSE),@true "",@echo "")
HIDE := $(if $(VERBOSE),,@)
INSTALLDEFAULTROOT := Crypto

.PHONY: coq clean update-_CoqProject cleanall install \
	install-coqprime clean-coqprime coqprime \
	specific-c specific-display display \
	specific non-specific lite only-heavy printlite \
	curves-proofs no-curves-proofs no-curves-proofs-non-specific \
	selected-specific selected-specific-display nonautogenerated-specific nonautogenerated-specific-display nonautogenerated-c selected-test selected-bench selected-c \
	test bench c \
	regenerate-curves

SORT_COQPROJECT = sed 's,[^/]*/,~&,g' | env LC_COLLATE=C sort | sed 's,~,,g' | uniq

FAST_TARGETS += archclean clean cleanall clean-coqprime printenv clean-old update-_CoqProject regenerate-curves Makefile.coq
SUPER_FAST_TARGETS += update-_CoqProject Makefile.coq regenerate-curves

SLOW :=
ifneq ($(filter-out $(SUPER_FAST_TARGETS),$(MAKECMDGOALS)),)
SLOW := 1
else
ifeq ($(MAKECMDGOALS),)
SLOW := 1
endif
endif

ifneq ($(SLOW),)
COQ_VERSION_PREFIX = The Coq Proof Assistant, version
COQ_VERSION := $(firstword $(subst $(COQ_VERSION_PREFIX),,$(shell "$(COQBIN)coqc" --version 2>/dev/null)))

-include Makefile.coq
endif

ifeq ($(filter curves-proofs no-curves-proofs no-curves-proofs-non-specific selected-specific selected-specific-display lite only-heavy printdeps printreversedeps printlite,$(MAKECMDGOALS)),)
-include etc/coq-scripts/Makefile.vo_closure
else
include etc/coq-scripts/Makefile.vo_closure
endif

.DEFAULT_GOAL := coq

update-_CoqProject::
	$(SHOW)'ECHO > _CoqProject'
	$(HIDE)(echo '-R $(SRC_DIR) $(MOD_NAME)'; echo '-R Bedrock Bedrock'; (git ls-files 'src/*.v' 'Bedrock/*.v' | $(SORT_COQPROJECT))) > _CoqProject

$(VOFILES): | coqprime

# add files to this list to prevent them from being built by default
UNMADE_VOFILES :=
UNMADE_C_FILES := \
	src/Specific/X25519/C64/fesub.c src/Specific/X25519/C64/feadd.c src/Specific/X25519/C64/fecarry.c \
	src/Specific/X25519/C64/fesub.h src/Specific/X25519/C64/feadd.h src/Specific/X25519/C64/fecarry.h \
	src/Specific/X25519/C32/fesub.c src/Specific/X25519/C32/feadd.c src/Specific/X25519/C32/fecarry.c \
	src/Specific/X25519/C32/fesub.h src/Specific/X25519/C32/feadd.h src/Specific/X25519/C32/fecarry.h
# files that are treated specially
SPECIAL_VOFILES := src/Specific/%Display.vo
SPECIFIC_GENERATED_VOFILES := src/Specific/solinas%.vo src/Specific/montgomery%.vo
# add files to this list to prevent them from being built as final
# targets by the "lite" target
LITE_UNMADE_VOFILES := src/Curves/Weierstrass/AffineProofs.vo \
	src/Curves/Weierstrass/Projective.vo \
	src/Specific/X2448/Karatsuba/C64/Synthesis.vo \
	src/Specific/NISTP256/AMD64/Synthesis.vo \
	src/Specific/NISTP256/AMD128/Synthesis.vo \
	src/Specific/X25519/C64/ladderstep.vo \
	src/Specific/X25519/C32/%.vo \
	$(SPECIFIC_GENERATED_VOFILES)
REGULAR_VOFILES := $(filter-out $(SPECIAL_VOFILES) $(UNMADE_VOFILES),$(VOFILES))
CURVES_PROOFS_PRE_VOFILES := $(filter src/Curves/%Proofs.vo,$(REGULAR_VOFILES))
NO_CURVES_PROOFS_UNMADE_VOFILES := src/Curves/Weierstrass/AffineProofs.vo
NO_CURVES_PROOFS_NON_SPECIFIC_UNMADE_VOFILES := src/Curves/Weierstrass/AffineProofs.vo src/Specific/%.vo

SELECTED_PATTERN := src/Specific/X25519/C64/% src/Specific/NISTP256/AMD64/% src/Specific/NISTP256/FancyMachine256/% third_party/%
SELECTED_SPECIFIC_PRE_VOFILES := $(filter $(SELECTED_PATTERN),$(REGULAR_VOFILES))

COQ_VOFILES := $(filter-out $(SPECIFIC_GENERATED_VOFILES),$(REGULAR_VOFILES))
SPECIFIC_VO := $(filter src/Specific/%,$(REGULAR_VOFILES))
NONAUTOGENERATED_SPECIFIC_VO := $(filter-out $(SPECIFIC_GENERATED_VOFILES),$(SPECIFIC_VO))
NON_SPECIFIC_VO := $(filter-out $(SPECIFIC_VO),$(REGULAR_VOFILES))
SPECIFIC_DISPLAY_VO := $(filter src/Specific/%Display.vo,$(filter-out $(UNMADE_VOFILES),$(VOFILES)))
NONAUTOGENERATED_SPECIFIC_DISPLAY_VO := $(filter-out $(SPECIFIC_GENERATED_VOFILES),$(SPECIFIC_DISPLAY_VO))
DISPLAY_VO := $(SPECIFIC_DISPLAY_VO)
DISPLAY_JAVA_VO := $(filter %JavaDisplay.vo,$(DISPLAY_VO))
DISPLAY_NON_JAVA_VO := $(filter-out $(DISPLAY_JAVA_VO),$(DISPLAY_VO))
SELECTED_SPECIFIC_DISPLAY_VO := $(filter $(SELECTED_PATTERN),$(DISPLAY_VO))
# computing the vo_reverse_closure is slow, so we only do it if we're
# asked to make the lite target
ifneq ($(filter printlite lite,$(MAKECMDGOALS)),)
LITE_ALL_UNMADE_VOFILES := $(foreach vo,$(LITE_UNMADE_VOFILES),$(call vo_reverse_closure,$(VOFILES),$(vo)))
LITE_VOFILES := $(filter-out $(LITE_ALL_UNMADE_VOFILES),$(COQ_VOFILES))
endif
ifneq ($(filter only-heavy,$(MAKECMDGOALS)),)
HEAVY_VOFILES := $(call vo_closure,$(LITE_UNMADE_VOFILES))
endif
ifneq ($(filter no-curves-proofs,$(MAKECMDGOALS)),)
NO_CURVES_PROOFS_ALL_UNMADE_VOFILES := $(foreach vo,$(NO_CURVES_PROOFS_UNMADE_VOFILES),$(call vo_reverse_closure,$(VOFILES),$(vo)))
NO_CURVES_PROOFS_VOFILES := $(filter-out $(NO_CURVES_PROOFS_ALL_UNMADE_VOFILES),$(COQ_VOFILES))
endif
ifneq ($(filter no-curves-proofs-non-specific,$(MAKECMDGOALS)),)
NO_CURVES_PROOFS_NON_SPECIFIC_ALL_UNMADE_VOFILES := $(foreach vo,$(NO_CURVES_PROOFS_NON_SPECIFIC_UNMADE_VOFILES),$(call vo_reverse_closure,$(VOFILES),$(vo)))
NO_CURVES_PROOFS_NON_SPECIFIC_VOFILES := $(filter-out $(NO_CURVES_PROOFS_NON_SPECIFIC_ALL_UNMADE_VOFILES),$(COQ_VOFILES))
endif
ifneq ($(filter curves-proofs,$(MAKECMDGOALS)),)
CURVES_PROOFS_VOFILES := $(call vo_closure,$(CURVES_PROOFS_PRE_VOFILES))
endif
ifneq ($(filter selected-specific,$(MAKECMDGOALS)),)
SELECTED_SPECIFIC_VOFILES := $(call vo_closure,$(SELECTED_SPECIFIC_PRE_VOFILES))
endif

specific: $(SPECIFIC_VO) coqprime
non-specific: $(NON_SPECIFIC_VO) coqprime
coq: $(COQ_VOFILES) coqprime
lite: $(LITE_VOFILES) coqprime
only-heavy: $(HEAVY_VOFILES) coqprime
curves-proofs: $(CURVES_PROOFS_VOFILES) coqprime
no-curves-proofs: $(NO_CURVES_PROOFS_VOFILES) coqprime
no-curves-proofs-non-specific: $(NO_CURVES_PROOFS_NON_SPECIFIC_VOFILES) coqprime
specific-display: $(SPECIFIC_DISPLAY_VO:.vo=.log) coqprime
specific-c: $(filter-out $(UNMADE_C_FILES),$(SPECIFIC_DISPLAY_VO:Display.vo=.c) $(SPECIFIC_DISPLAY_VO:Display.vo=.h)) coqprime
selected-specific: $(SELECTED_SPECIFIC_VOFILES) coqprime
selected-specific-display: $(SELECTED_SPECIFIC_DISPLAY_VO:.vo=.log) coqprime
selected-c: $(filter-out $(UNMADE_C_FILES),$(SELECTED_SPECIFIC_DISPLAY_VO:Display.vo=.c) $(SELECTED_SPECIFIC_DISPLAY_VO:Display.vo=.h)) coqprime
nonautogenerated-specific: $(NONAUTOGENERATED_SPECIFIC_VOFILES) coqprime
nonautogenerated-specific-display: $(NONAUTOGENERATED_SPECIFIC_DISPLAY_VO:.vo=.log) coqprime
nonautogenerated-c: $(filter-out $(UNMADE_C_FILES),$(NONAUTOGENERATED_SPECIFIC_DISPLAY_VO:Display.vo=.c) $(NONAUTOGENERATED_SPECIFIC_DISPLAY_VO:Display.vo=.h)) coqprime
display: $(DISPLAY_VO:.vo=.log) coqprime

regenerate-curves::
	./regenerate-curves.sh

# extra target for faster coqdep
.PHONY: src/Specific/.autgenerated-deps
src/Specific/.autgenerated-deps:
	$(SHOW)'COQDEP $@'
	$(HIDE)$(COQDEP) $(COQLIBS) -dyndep var -c $(SPECIFIC_GENERATED_VOFILES:.vo=.v) $(redir_if_ok)

.PHONY: fast-autogenerated-deps
fast-autogenerated-deps: src/Specific/.autgenerated-deps
	$(SHOW)'CP .v.d'
	$(HIDE)for i in $(SPECIFIC_GENERATED_VOFILES:.vo=.v.d); do cp -f src/Specific/.autgenerated-deps $$i; done

printlite::
	@echo 'Files Made:'
	@for i in $(sort $(LITE_VOFILES)); do echo $$i; done
	@echo
	@echo
	@echo 'Files Not Made:'
	@for i in $(sort $(LITE_ALL_UNMADE_VOFILES)); do echo $$i; done

COQPRIME_FOLDER := coqprime
ifneq ($(filter 8.5%,$(COQ_VERSION)),) # 8.5
else
ifneq ($(PROFILE),)
OTHERFLAGS += -profile-ltac
endif
OTHERFLAGS += -w "-notation-overridden"
endif

COQPATH?=${CURDIR}/$(COQPRIME_FOLDER)
export COQPATH

coqprime:
	$(MAKE) --no-print-directory -C $(COQPRIME_FOLDER)

clean-coqprime:
	$(MAKE) --no-print-directory -C $(COQPRIME_FOLDER) clean

install-coqprime:
	$(MAKE) --no-print-directory -C $(COQPRIME_FOLDER) install

etc/tscfreq: etc/tscfreq.c
	gcc etc/tscfreq.c -s -Os -o etc/tscfreq

Makefile.coq: Makefile _CoqProject
	$(SHOW)'COQ_MAKEFILE -f _CoqProject > $@'
	$(HIDE)$(COQBIN)coq_makefile -f _CoqProject INSTALLDEFAULTROOT = $(INSTALLDEFAULTROOT) -o Makefile-old && cat Makefile-old | sed s'/^printenv:/printenv::/g' | sed s'/^printenv:::/printenv::/g' > $@ && rm -f Makefile-old

$(DISPLAY_NON_JAVA_VO:.vo=.log) : %Display.log : %.vo %Display.v src/Compilers/Z/CNotations.vo src/Specific/Framework/IntegrationTestDisplayCommon.vo
	$(SHOW)"COQC $*Display > $@"
	$(HIDE)$(COQC) $(COQDEBUG) $(COQFLAGS) $*Display.v | sed s'/\r\n/\n/g' > $@.tmp && mv -f $@.tmp $@

DISPLAY_X25519_C64_VO := $(filter src/Specific/X25519/C64/%,$(DISPLAY_NON_JAVA_VO))
DISPLAY_X25519_C32_VO := $(filter src/Specific/X25519/C32/%,$(DISPLAY_NON_JAVA_VO))
DISPLAY_NON_JAVA_C32_VO := $(DISPLAY_X25519_C32_VO)
DISPLAY_NON_JAVA_C64_VO := $(filter-out $(DISPLAY_NON_JAVA_C32_VO) $(SPECIFIC_GENERATED_VOFILES),$(DISPLAY_NON_JAVA_VO))
DISPLAY_GENERATED_VO := $(filter $(SPECIFIC_GENERATED_VOFILES),$(DISPLAY_NON_JAVA_VO))
DISPLAY_NON_GENERATED_VO := $(filter-out $(DISPLAY_GENERATED_VO),$(DISPLAY_NON_JAVA_VO))

c: $(filter-out $(UNMADE_C_FILES),$(DISPLAY_NON_JAVA_VO:Display.vo=.c) $(DISPLAY_NON_GENERATED_VO:Display.vo=.h))

$(DISPLAY_NON_JAVA_C64_VO:Display.vo=.c) : %.c : %Display.log extract-function.sh
	BITWIDTH=64 FIAT_CRYPTO_EXTRACT_FUNCTION_IS_ASM="" ./extract-function.sh $(patsubst %Display.log,%,$(notdir $<)) < $< > $@

$(DISPLAY_NON_JAVA_C32_VO:Display.vo=.c) : %.c : %Display.log extract-function.sh
	BITWIDTH=32 FIAT_CRYPTO_EXTRACT_FUNCTION_IS_ASM="" ./extract-function.sh $(patsubst %Display.log,%,$(notdir $<)) < $< > $@

$(DISPLAY_NON_JAVA_C64_VO:Display.vo=.h) : %.h : %Display.log extract-function-header.sh
	BITWIDTH=64 ./extract-function-header.sh $(patsubst %Display.log,%,$(notdir $<)) < $< > $@

$(DISPLAY_NON_JAVA_C32_VO:Display.vo=.h) : %.h : %Display.log extract-function-header.sh
	BITWIDTH=32 ./extract-function-header.sh $(patsubst %Display.log,%,$(notdir $<)) < $< > $@

$(DISPLAY_GENERATED_VO:Display.vo=.c) : %.c : %Display.log src/Specific/Framework/bench/prettyprint.py
	./src/Specific/Framework/bench/prettyprint.py $(patsubst %Display.log,%,$(notdir $<)) < $< > $@

$(DISPLAY_JAVA_VO:.vo=.log) : %JavaDisplay.log : %.vo %JavaDisplay.v src/Compilers/Z/JavaNotations.vo src/Specific/Framework/IntegrationTestDisplayCommon.vo
	$(SHOW)"COQC $*JavaDisplay > $@"
	$(HIDE)$(COQC) $(COQDEBUG) $(COQFLAGS) $*JavaDisplay.v | sed s'/\r\n/\n/g' > $@.tmp && mv -f $@.tmp $@

TEST_BINARIES := \
	src/Specific/X25519/C64/test \
	src/Specific/NISTP256/AMD64/test/feadd_test \
	src/Specific/NISTP256/AMD64/test/femul_test \
	src/Specific/NISTP256/AMD64/test/p256_test \
	src/Specific/NISTP256/AMD64/icc/p256_test
RUN_TEST_BINARIES := $(addsuffix -run,$(TEST_BINARIES))
MEASUREMENTS := \
	src/Specific/X25519/C64/measurements.txt \
	third_party/openssl-curve25519/measurements.txt \
	third_party/curve25519-donna-c64/measurements.txt \
	third_party/openssl-nistz256-amd64/measurements.txt \
	third_party/openssl-nistz256-adx/measurements.txt \
	third_party/openssl-nistp256c64/measurements.txt \
	src/Specific/NISTP256/AMD64/measurements.txt \
	src/Specific/NISTP256/AMD64/icc/measurements.txt
MEASURE_BINARIES := $(addsuffix measure,$(dir $(MEASUREMENTS)))

SELECTED_TEST_BINARIES := $(filter $(SELECTED_PATTERN),$(TEST_BINARIES))
RUN_SELECTED_TEST_BINARIES := $(filter $(SELECTED_PATTERN),$(RUN_TEST_BINARIES))
SELECTED_MEASUREMENTS := $(filter $(SELECTED_PATTERN),$(MEASUREMENTS))

src/Specific/X25519/C64/test src/Specific/X25519/C64/measure: $(filter-out $(UNMADE_C_FILES),$(DISPLAY_X25519_C64_VO:Display.vo=.c) $(DISPLAY_X25519_C64_VO:Display.vo=.h)) src/Specific/X25519/C64/scalarmult.c
src/Specific/X25519/C64/test: src/Specific/X25519/C64/compiler.sh src/Specific/X25519/x25519_test.c
src/Specific/X25519/C64/test: INCLUDE_FOLDER=src/Specific/X25519/C64
src/Specific/X25519/C64/measure: UUT=crypto_scalarmult_bench
src/Specific/X25519/C64/measurements.txt: COUNT=2047

third_party/openssl-curve25519/measure: third_party/openssl-curve25519/crypto_scalarmult_bench.c third_party/openssl-curve25519/ec_curve25519.c third_party/openssl-curve25519/ec_curve25519.h
third_party/openssl-curve25519/measure: UUT=crypto_scalarmult_bench
third_party/openssl-curve25519/measurements.txt: COUNT=2047

third_party/curve25519-donna-c64/measure: third_party/curve25519-donna-c64/crypto_scalarmult_bench.c third_party/curve25519-donna-c64/curve25519-donna-c64.c
third_party/curve25519-donna-c64/measure: UUT=crypto_scalarmult_bench
third_party/curve25519-donna-c64/measurements.txt: COUNT=2047

third_party/openssl-nistz256-amd64/measure: third_party/openssl-nistz256-amd64/bench_madd.c third_party/openssl-nistz256-amd64/cpu_intel.c third_party/openssl-nistz256-amd64/ecp_nistz256-x86_64.s third_party/openssl-nistz256-amd64/nistz256.h
third_party/openssl-nistz256-amd64/measure: UUT=bench_madd
third_party/openssl-nistz256-amd64/measurements.txt: COUNT=65535

third_party/openssl-nistz256-adx/measure: third_party/openssl-nistz256-adx/bench_madd.c third_party/openssl-nistz256-adx/cpu_intel.c third_party/openssl-nistz256-adx/ecp_nistz256-x86_64.s third_party/openssl-nistz256-adx/nistz256.h
third_party/openssl-nistz256-adx/measure: UUT=bench_madd
third_party/openssl-nistz256-adx/measurements.txt: COUNT=65535

third_party/openssl-nistp256c64/measure: third_party/openssl-nistp256c64/bench_madd.c third_party/openssl-nistp256c64/ecp_nistp256.c third_party/openssl-nistp256c64/ecp_nistp256.h
third_party/openssl-nistp256c64/measure: UUT=bench_madd
third_party/openssl-nistp256c64/measurements.txt: COUNT=65535

src/Specific/NISTP256/AMD64/measure: src/Specific/NISTP256/AMD64/bench_madd.c src/Specific/NISTP256/AMD64/feadd.h src/Specific/NISTP256/AMD64/feadd.c src/Specific/NISTP256/AMD64/femul.h src/Specific/NISTP256/AMD64/femul.c src/Specific/NISTP256/AMD64/fenz.h src/Specific/NISTP256/AMD64/fenz.c src/Specific/NISTP256/AMD64/feopp.h src/Specific/NISTP256/AMD64/feopp.c src/Specific/NISTP256/AMD64/fesub.h src/Specific/NISTP256/AMD64/fesub.c src/Specific/NISTP256/AMD64/p256_jacobian_add_affine.c liblow/cmovznz.c
src/Specific/NISTP256/AMD64/measure: UUT=bench_madd
src/Specific/NISTP256/AMD64/measurements.txt: COUNT=65535

src/Specific/NISTP256/AMD64/icc/measure: src/Specific/NISTP256/AMD64/p256.h src/Specific/NISTP256/AMD64/icc/icc17_p256_jacobian_add_affine.s src/Specific/NISTP256/AMD64/bench_madd.c liblow/cmovznz.c
src/Specific/NISTP256/AMD64/icc/measure: UUT=bench_madd
src/Specific/NISTP256/AMD64/icc/measurements.txt: COUNT=65535


src/Specific/NISTP256/AMD64/test/feadd_test src/Specific/NISTP256/AMD64/test/femul_test src/Specific/NISTP256/AMD64/test/p256_test: src/Specific/NISTP256/AMD64/compiler.sh liblow/cmovznz.c
src/Specific/NISTP256/AMD64/test/feadd_test src/Specific/NISTP256/AMD64/test/femul_test src/Specific/NISTP256/AMD64/test/p256_test: INCLUDE_FOLDER=src/Specific/NISTP256/AMD64/

src/Specific/NISTP256/AMD64/test/feadd_test: src/Specific/NISTP256/AMD64/feadd.h src/Specific/NISTP256/AMD64/feadd.c src/Specific/NISTP256/AMD64/test/feadd_test.c

src/Specific/NISTP256/AMD64/test/femul_test: src/Specific/NISTP256/AMD64/femul.h src/Specific/NISTP256/AMD64/femul.c src/Specific/NISTP256/AMD64/test/femul_test.c

src/Specific/NISTP256/AMD64/test/p256_test: src/Specific/NISTP256/AMD64/test/p256_test.c src/Specific/NISTP256/AMD64/feadd.c src/Specific/NISTP256/AMD64/feadd.h src/Specific/NISTP256/AMD64/femul.c src/Specific/NISTP256/AMD64/femul.h src/Specific/NISTP256/AMD64/fenz.c src/Specific/NISTP256/AMD64/fenz.h src/Specific/NISTP256/AMD64/fesub.c src/Specific/NISTP256/AMD64/fesub.h src/Specific/NISTP256/AMD64/p256_jacobian_add_affine.c src/Specific/NISTP256/AMD64/p256.h

src/Specific/NISTP256/AMD64/icc/p256_test: src/Specific/NISTP256/AMD64/icc/compiler.sh src/Specific/NISTP256/AMD64/test/p256_test.c src/Specific/NISTP256/AMD64/icc/icc17_p256_jacobian_add_affine.s src/Specific/NISTP256/AMD64/p256.h
src/Specific/NISTP256/AMD64/icc/p256_test: INCLUDE_FOLDER=src/Specific/NISTP256/AMD64/

$(TEST_BINARIES):
	$(filter %/compiler.sh,$^) -o $@ -I liblow -I $(INCLUDE_FOLDER) $(filter %.c %.s,$^)

$(MEASURE_BINARIES) : %/measure : %/compiler.sh measure.c
	$*/compiler.sh -o $@ -I liblow -I $* $(filter %.c %.s,$^) -D UUT=$(UUT)

$(MEASUREMENTS) : %/measurements.txt : %/measure capture.sh etc/machine.sh etc/cpufreq etc/tscfreq
	./capture.sh $* $(COUNT)

src/Specific/NISTP256/AMD64/icc/combined.c: liblow/cmovznz.c src/Specific/NISTP256/AMD64/feadd.c src/Specific/NISTP256/AMD64/femul.c src/Specific/NISTP256/AMD64/fenz.c src/Specific/NISTP256/AMD64/fesub.c src/Specific/NISTP256/AMD64/p256_jacobian_add_affine.c extract-function.sh
	(cd src/Specific/NISTP256/AMD64 && ( BITWIDTH=64 FIAT_CRYPTO_EXTRACT_FUNCTION_IS_ASM="" ../../../../extract-function.sh "stdint" < /dev/null | grep -v stdint && sed 's:^uint64_t:static inline &:' ../../../../liblow/cmovznz.c && echo fenz.c feadd.c fesub.c femul.c p256_jacobian_add_affine.c | xargs -n1 grep -A99999 void -- ) | sed 's:^void force_inline:static inline void force_inline:' | grep -v liblow > icc/combined.c )

GENERATED_FOLDERS := $(sort $(dir $(filter $(SPECIFIC_GENERATED_VOFILES),$(REGULAR_VOFILES))))
GENERATED_PY_MEASUREMENTS := $(addsuffix montladder.log,$(GENERATED_FOLDERS))
GENERATED_GMPXX := $(addsuffix gmpxx,$(GENERATED_FOLDERS))
GENERATED_GMPXX_MEASUREMENTS := $(addsuffix .log,$(GENERATED_GMPXX))
GENERATED_GMPVAR := $(addsuffix gmpvar,$(GENERATED_FOLDERS))
GENERATED_GMPVAR_MEASUREMENTS := $(addsuffix .log,$(GENERATED_GMPVAR))
GENERATED_GMPSEC := $(addsuffix gmpsec,$(GENERATED_FOLDERS))
GENERATED_GMPSEC_MEASUREMENTS := $(addsuffix .log,$(GENERATED_GMPSEC))
GENERATED_FIBE := $(addsuffix fibe,$(GENERATED_FOLDERS))
GENERATED_FIBE_MEASUREMENTS := $(addsuffix .log,$(GENERATED_FIBE))

generated-benchmarks: $(GENERATED_FIBE) $(GENERATED_GMPSEC) $(GENERATED_GMPVAR) $(GENERATED_GMPXX)

$(GENERATED_PY_MEASUREMENTS) : %/montladder.log : %/py_interpreter.sh src/Specific/Framework/bench/montladder.py
	sh $*/py_interpreter.sh src/Specific/Framework/bench/montladder.py > $@

$(GENERATED_GMPXX) : %/gmpxx : %/compilerxx.sh src/Specific/Framework/bench/gmpxx.cpp
	sh $*/compilerxx.sh src/Specific/Framework/bench/gmpxx.cpp -lgmp -lgmpxx -o $@

$(GENERATED_GMPXX_MEASUREMENTS) : %/gmpxx.log : %/gmpxx
	$(STDTIME) $< 2>&1 | tee $@

$(GENERATED_GMPVAR) : %/gmpvar : %/compiler.sh src/Specific/Framework/bench/gmpvar.c
	sh $*/compiler.sh src/Specific/Framework/bench/gmpvar.c -lgmp -o $@

$(GENERATED_GMPVAR_MEASUREMENTS) : %/gmpvar.log : %/gmpvar
	$(STDTIME) $< 2>&1 | tee $@

$(GENERATED_GMPSEC) : %/gmpsec : %/compiler.sh src/Specific/Framework/bench/gmpsec.c
	sh $*/compiler.sh src/Specific/Framework/bench/gmpsec.c -lgmp -o $@

$(GENERATED_GMPSEC_MEASUREMENTS) : %/gmpsec.log : %/gmpsec
	$(STDTIME) $< 2>&1 | tee $@

$(GENERATED_FIBE) : %/fibe : %/compiler.sh src/Specific/Framework/bench/fibe.c %/feadd.c %/femul.c %/fesquare.c %/fesub.c liblow/liblow.h liblow/cmovznz.c
	sh $*/compiler.sh -I liblow/ liblow/cmovznz.c src/Specific/Framework/bench/fibe.c -I $*/ -o $@

$(GENERATED_FIBE_MEASUREMENTS) : %/fibe.log : %/fibe
	$(STDTIME) $< 2>&1 | tee $@

.PHONY: generated-py-bench
generated-py-bench: $(GENERATED_PY_MEASUREMENTS)
	head -999999 $?

.PHONY: generated-gmpxx-bench
generated-gmpxx-bench: $(GENERATED_GMPXX_MEASUREMENTS)
	head -999999 $?

.PHONY: generated-gmpvar-bench
generated-gmpvar-bench: $(GENERATED_GMPVAR_MEASUREMENTS)
	head -999999 $?

.PHONY: generated-gmpsec-bench
generated-gmpsec-bench: $(GENERATED_GMPSEC_MEASUREMENTS)
	head -999999 $?

.PHONY: generated-fibe-bench
generated-fibe-bench: $(GENERATED_FIBE_MEASUREMENTS)
	head -999999 $?

bench: $(MEASUREMENTS)
	head -999999 $?

selected-bench: $(SELECTED_MEASUREMENTS)
	head -999999 $?


.PHONY: $(RUN_TEST_BINARIES)
$(RUN_TEST_BINARIES) : %-run : %
	$<

test: $(RUN_TEST_BINARIES)

selected-test: $(RUN_SELECTED_TEST_BINARIES)

clean::
	rm -f Makefile.coq remake_curves.log

cleanall:: clean clean-coqprime

install: coq install-coqprime

printenv::
	@echo "COQPATH =        $$COQPATH"

printdeps::
	$(HIDE)$(foreach vo,$(filter %.vo,$(MAKECMDGOALS)),echo '$(vo): $(call vo_closure,$(vo))'; )

printreversedeps::
	$(HIDE)$(foreach vo,$(filter %.vo,$(MAKECMDGOALS)),echo '$(vo): $(call vo_reverse_closure,$(VOFILES),$(vo))'; )
